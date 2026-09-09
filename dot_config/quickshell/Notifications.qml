import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

// Desktop notification popups (org.freedesktop.Notifications over DBus, the
// same protocol notify-send speaks). Instantiating NotificationServer is what
// claims the DBus name, so only one of these should exist in the shell.
//
// This is its own top-level layer-shell surface rather than a widget bolted
// onto the bar window: popups need to float above every other window,
// anywhere on screen, independent of the bar's own size and position.
PanelWindow {
    id: root


    // How far down to sit, so popups start below the bar rather than
    // covering it. Bound from shell.qml to the bar's own height.
    property int topOffset: 0

    // Live notifications, most recent last. Plain reassignment (rather than
    // mutating in place) because QML's change notification for a Repeater's
    // `model` only fires on assignment, not on array mutation.
    property var popups: []

    function removePopup(notification) {
        root.popups = root.popups.filter(n => n !== notification);
    }

    // History for NotificationHistoryButton's dropdown, most recent first.
    // Snapshotted as plain data rather than kept as live Notification
    // references: history entries just need to be displayed, never
    // dismissed/expired, so there's no reason to hold the DBus-backed
    // objects (and their `tracked` keep-alive) around any longer than the
    // popup itself needs them.
    readonly property int maxHistory: 50
    property var history: []
    // Own id counter for history entries - they're plain JS object literals,
    // not the QObject-backed Notification instances popups.filter() above
    // can safely compare by reference. Those *don't* keep reference
    // identity once round-tripped through a ListView's `model`/`modelData`
    // (observed directly: removeHistoryEntry's `r !== record` matched
    // every entry, including the one that was supposedly just clicked), so
    // removal has to go by an explicit id instead.
    property int nextHistoryId: 0

    function pushHistory(notification) {
        const record = {
            id: root.nextHistoryId++,
            summary: notification.summary,
            body: notification.body,
            appName: notification.appName,
            appIcon: notification.appIcon,
            image: notification.image,
            urgency: notification.urgency,
            time: Date.now(),
        };
        root.history = [record, ...root.history].slice(0, root.maxHistory);
    }

    function clearHistory() { root.history = []; }

    function removeHistoryEntry(id) {
        root.history = root.history.filter(r => r.id !== id);
    }

    anchors.top: true
    anchors.right: true
    margins.top: root.topOffset + 8
    margins.right: 8

    // Overlay so popups sit above fullscreen windows too; no exclusive zone
    // so this surface never reserves screen space or shoves other windows
    // around the way the bar does.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:notifications"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: 0
    focusable: false

    color: "transparent"

    // Zero-height layer surfaces are asking for compositor trouble, and an
    // empty column has nothing to show anyway - so the whole window comes
    // and goes with the popup list instead of sitting there at 0x0.
    visible: root.popups.length > 0

    implicitWidth: 340
    implicitHeight: Math.max(1, column.implicitHeight)

    NotificationServer {
        id: server

        // Only advertise what NotificationBubble below actually renders -
        // claiming more just invites apps to send markup/actions we'd
        // silently drop.
        bodySupported: true
        bodyMarkupSupported: false
        bodyHyperlinksSupported: false
        bodyImagesSupported: false
        imageSupported: true
        actionsSupported: false
        actionIconsSupported: false
        persistenceSupported: false

        onNotification: notification => {
            // Untracked notifications are destroyed the moment this handler
            // returns; tracking keeps the object (and its closed signal)
            // alive for as long as we hold a reference.
            notification.tracked = true;
            root.popups = root.popups.concat([notification]);
            root.pushHistory(notification);
        }
    }

    Column {
        id: column
        width: root.width
        spacing: 8

        Repeater {
            model: root.popups

            NotificationBubble {
                id: bubble
                required property var modelData

                width: column.width
                notification: modelData

                // The closed signal fires whichever way the notification
                // went away - our own timeout, a click-to-dismiss, or the
                // sending app withdrawing/replacing it over DBus - so this
                // is the one place a dismissal starts. The popup stays in
                // `popups` (and the window stays mapped/sized around it)
                // until it's actually finished sliding out.
                Connections {
                    target: bubble.notification
                    function onClosed() { bubble.playDismiss(); }
                }

                // Untrack once it's really gone: history already has its
                // own snapshot of anything worth keeping, so there's no
                // reason to hold the live object (and let it dodge GC) any
                // longer than the slide-out took.
                onDismissFinished: {
                    root.removePopup(bubble.modelData);
                    bubble.modelData.tracked = false;
                }
            }
        }
    }
}
