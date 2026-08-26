import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick

// Full-height notification history, sliding in from the right edge. Its own
// top-level layer-shell surface (same reasoning as AppLauncher.qml: a
// bar-anchored popup can't cover the whole screen height or float above
// everything), spanning the full output so the click-outside-to-close scrim
// has somewhere to catch a click, with just a fixed-width strip on the
// right actually visible.
PanelWindow {
    id: root

    property color colBg: "#1a1b26"
    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colBlue: "#7aa2f7"
    property color colRed: "#f7768e"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14

    // [{ id, summary, body, appName, appIcon, image, urgency, time }, ...],
    // most recent first. Owned by Notifications.qml.
    required property var history
    signal clearRequested()
    // The dismissed entry's id (not the record itself - see the comment on
    // Notifications.qml's nextHistoryId for why).
    signal dismissRequested(int id)

    readonly property int paneWidth: 360
    readonly property int slideDuration: 220

    // `open` flips instantly (drives the slide animation's target right
    // away); `visible` lags behind it on the way out so the surface stays
    // mapped - and the slide-closed animation stays visible - for exactly
    // as long as that animation takes.
    property bool open: false

    function show() { root.open = true; }
    function hide() { root.open = false; }
    function toggle() { root.open ? root.hide() : root.show(); }

    onOpenChanged: {
        if (root.open) closeTimer.stop(), root.reallyVisible = true;
        else closeTimer.restart();
    }

    property bool reallyVisible: false
    Timer {
        id: closeTimer
        interval: root.slideDuration
        onTriggered: root.reallyVisible = false
    }

    visible: root.reallyVisible

    // No explicit top margin needed to clear the bar, unlike Notifications.qml's
    // popups: Hyprland already keeps a surface anchored to an edge from
    // overlapping another surface's exclusive zone there (the bar reserves
    // its own height), so this already starts right below it for free. An
    // explicit margins.top here previously *added* to that, double-offsetting
    // it down by the bar's height a second time.
    anchors { top: true; bottom: true; left: true; right: true }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell:notification-history"
    // Deliberately never anything but None: giving this surface OnDemand
    // (or Exclusive) keyboard focus - even statically, even without ever
    // forcing it - was observed to corrupt click hit-testing on *other*
    // surfaces (the bar's own buttons) whenever this one (re)maps, unless
    // it happened to stay mapped the whole session. Rather than depend on
    // that, this surface just never asks for keyboard focus at all; Escape
    // is instead handled on the bar itself (shell.qml), which does hold
    // focus reliably since it never remaps.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusiveZone: 0
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"

    // Same reasoning as AppLauncher's mask: this surface is fully
    // transparent, and Qt/Wayland only makes a translucent surface's opaque
    // area clickable by default - without this the scrim below would never
    // actually receive a click.
    mask: Region {
        width: root.width
        height: root.height
    }

    // Click-outside-to-close. Disabled (rather than just relying on it being
    // covered by the closing pane) the moment `open` goes false, so it
    // doesn't keep eating clicks meant for whatever's underneath for the
    // remainder of the slide-out animation.
    MouseArea {
        anchors.fill: parent
        enabled: root.open
        onClicked: root.hide()
    }

    Rectangle {
        id: pane
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        width: root.paneWidth
        // Slides via rightMargin rather than x directly: anchoring right
        // and pushing off with a negative margin depends only on this
        // item's own (fixed) width, never on parent.width. Driving it off
        // parent.width instead (`x: open ? parent.width - width :
        // parent.width`) was the actual bug behind the very-first-open
        // wrong-direction slide - on a freshly mapped layer-shell surface,
        // parent.width can still be reporting a stale/zero size for a
        // moment right as `open` flips true, so both the closed *and* open
        // targets glitch to bogus values (e.g. 0, -360) before correcting,
        // and the Behavior animates through that correction, reading as a
        // slide in from the left.
        anchors.rightMargin: root.open ? 0 : -width
        Behavior on anchors.rightMargin {
            NumberAnimation { duration: root.slideDuration; easing.type: Easing.OutCubic }
        }

        color: root.colBg
        border { width: 1; color: root.colMuted }

        // Swallows clicks anywhere on the pane so they don't fall through
        // to the scrim behind it and close the pane out from under them.
        MouseArea { anchors.fill: parent }

        // Ticks only while the pane is open, purely to keep the "Xm ago"
        // labels below honest as time passes - no point refreshing them
        // while nobody can see them.
        Timer {
            interval: 30000
            running: root.open
            repeat: true
            onTriggered: relativeTimeTick.tick = !relativeTimeTick.tick
        }
        QtObject { id: relativeTimeTick; property bool tick: false }

        function relativeTime(time) {
            // Referencing tick (unused otherwise) is what makes this
            // re-evaluate as the Timer above ticks.
            void relativeTimeTick.tick;
            const seconds = Math.max(0, Math.round((Date.now() - time) / 1000));
            if (seconds < 60) return "just now";
            const minutes = Math.round(seconds / 60);
            if (minutes < 60) return `${minutes}m ago`;
            const hours = Math.round(minutes / 60);
            if (hours < 24) return `${hours}h ago`;
            return `${Math.round(hours / 24)}d ago`;
        }

        Item {
            id: header
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
            height: 24

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Notifications"
                color: root.colFg
                font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
            }

            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                visible: root.history.length > 0
                text: "Clear all"
                color: clearHover.hovered ? root.colRed : root.colMuted
                font { family: root.fontFamily; pixelSize: root.fontSize - 3 }

                HoverHandler { id: clearHover; cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: root.clearRequested() }
            }
        }

        Text {
            anchors { left: parent.left; right: parent.right; top: header.bottom; margins: 12; topMargin: 24 }
            visible: root.history.length === 0
            text: "No notifications yet"
            color: root.colMuted
            horizontalAlignment: Text.AlignHCenter
            font { family: root.fontFamily; pixelSize: root.fontSize - 2 }
        }

        ListView {
            anchors {
                left: parent.left; right: parent.right; bottom: parent.bottom
                top: header.bottom; margins: 12; topMargin: 8
            }
            clip: true
            visible: root.history.length > 0
            spacing: 6
            model: root.history

            delegate: Rectangle {
                id: entry
                required property var modelData

                width: ListView.view.width
                implicitHeight: entryContent.implicitHeight + 12
                color: "transparent"
                radius: 4
                border { width: 1; color: root.colMuted }

                readonly property color accent:
                    entry.modelData.urgency === NotificationUrgency.Critical ? root.colRed
                        : root.colBlue

                // Slides fully clear of the pane (clipped by the ListView
                // above) before actually asking Notifications.qml to drop
                // it, rather than disappearing instantly.
                NumberAnimation {
                    id: slideOutAnim
                    target: entry
                    property: "x"
                    to: entry.width + 40
                    duration: 220
                    easing.type: Easing.InCubic
                    onFinished: root.dismissRequested(entry.modelData.id)
                }

                Rectangle {
                    anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
                    width: 3
                    color: entry.accent
                }

                Item {
                    id: dismissButton
                    // Padded well past the glyph itself - a bare fontSize-ish
                    // "×" is a punishingly small click target on its own.
                    anchors { right: parent.right; top: parent.top; margins: 2 }
                    width: 20
                    height: 20

                    Text {
                        anchors.centerIn: parent
                        text: "×"
                        color: dismissArea.containsMouse ? root.colRed : root.colMuted
                        font { family: root.fontFamily; pixelSize: root.fontSize + 2 }
                    }

                    // MouseArea rather than Tap/HoverHandler: inside a
                    // ListView delegate, TapHandler's tap recognition was
                    // observed to eat clicks entirely (hover still worked,
                    // onTapped never fired) - matches AppLauncherEntry's row
                    // handlers below, which use MouseArea for the same
                    // reason.
                    MouseArea {
                        id: dismissArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (!slideOutAnim.running) slideOutAnim.start()
                    }
                }

                Column {
                    id: entryContent
                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
                    // rightMargin wider than the left to leave room for
                    // dismissButton in the corner above.
                    anchors { leftMargin: 12; rightMargin: 22 }
                    spacing: 2

                    Item {
                        width: parent.width
                        height: summaryText.implicitHeight

                        Text {
                            id: summaryText
                            anchors { left: parent.left; right: timeText.left; rightMargin: 6 }
                            text: entry.modelData.appName !== ""
                                ? `${entry.modelData.appName}: ${entry.modelData.summary}`
                                : entry.modelData.summary
                            color: root.colFg
                            font { family: root.fontFamily; pixelSize: root.fontSize - 2; bold: true }
                            elide: Text.ElideRight
                        }

                        Text {
                            id: timeText
                            anchors { right: parent.right; verticalCenter: summaryText.verticalCenter }
                            text: pane.relativeTime(entry.modelData.time)
                            color: root.colMuted
                            font { family: root.fontFamily; pixelSize: root.fontSize - 4 }
                        }
                    }

                    Text {
                        width: parent.width
                        visible: text !== ""
                        text: entry.modelData.body
                        color: root.colMuted
                        font { family: root.fontFamily; pixelSize: root.fontSize - 3 }
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
