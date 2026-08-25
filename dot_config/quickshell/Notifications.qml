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

    property color colBg: "#1a1b26"
    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colBlue: "#7aa2f7"
    property color colYellow: "#e0af68"
    property color colRed: "#f7768e"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14

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
                colBg: root.colBg
                colFg: root.colFg
                colMuted: root.colMuted
                colBlue: root.colBlue
                colYellow: root.colYellow
                colRed: root.colRed
                fontFamily: root.fontFamily
                fontSize: root.fontSize

                // The closed signal fires whichever way the notification
                // went away - our own timeout, a click-to-dismiss, or the
                // sending app withdrawing/replacing it over DBus - so this
                // is the one place popups get pruned from the list.
                Connections {
                    target: bubble.notification
                    function onClosed() { root.removePopup(bubble.modelData); }
                }
            }
        }
    }
}
