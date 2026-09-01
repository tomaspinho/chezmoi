import Quickshell
import Quickshell.Services.Notifications
import QtQuick
import Quickshell.Widgets

// A single popup box for one live Notification. Purely presentational and
// self-contained (owns its own auto-expire timer); Notifications.qml decides
// when the underlying notification is gone and prunes it from the list.
Rectangle {
    id: bubble

    required property var notification


    // Every binding that reads `notification` goes through `?.`: on dismissal
    // Notifications.qml reassigns its `popups` array, and the Repeater
    // re-evaluates this delegate's bindings with a null modelData once before
    // destroying it. Harmless in effect, but unguarded it logged five
    // TypeErrors per notification.

    // Urgency maps to the accent stripe down the left edge, same idea as a
    // dunst/mako color scheme: normal reads as the bar's usual accent,
    // low fades into the furniture, critical demands attention.
    readonly property color accent: notification?.urgency === NotificationUrgency.Critical ? Theme.colRed
        : notification?.urgency === NotificationUrgency.Low ? Theme.colMuted
        : Theme.colBlue

    // Per the notification spec, expireTimeout -1 means "server picks the
    // default" and 0 means "never expire on its own". Critical notifications
    // default to sticky (matches dunst/mako's convention) since they're
    // usually something the user must act on, not glance past.
    readonly property int effectiveTimeout: {
        const timeout = notification?.expireTimeout ?? -1;
        if (timeout > 0) return timeout;
        if (timeout === 0) return 0;
        return notification?.urgency === NotificationUrgency.Critical ? 0 : 5000;
    }

    readonly property string iconSource: {
        const image = notification?.image ?? "";
        if (image !== "") return image;
        const appIcon = notification?.appIcon ?? "";
        return appIcon !== "" ? Quickshell.iconPath(appIcon, "") : "";
    }

    // Notifications.qml owns removing this from its list, same as always,
    // but only once this has actually finished sliding out - see
    // playDismiss()/dismissFinished below.
    signal dismissFinished()

    function playDismiss() {
        if (!slideOutAnim.running) slideOutAnim.start();
    }

    NumberAnimation {
        id: slideOutAnim
        target: bubble
        property: "x"
        // Past the bubble's own width is enough to clear it - the window
        // behind it is exactly as wide as the bubble and anchored flush to
        // the screen's right edge, so this reads as sliding off the
        // screen, not just off the bubble's starting position.
        to: bubble.width + 40
        duration: 220
        easing.type: Easing.InCubic
        onFinished: bubble.dismissFinished()
    }

    implicitHeight: content.implicitHeight + 16
    color: Theme.colBg
    border { width: 1; color: Theme.colMuted }
    clip: true

    Rectangle {
        // left accent stripe
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
        width: 3
        color: bubble.accent
    }

    Row {
        id: content
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter }
        // rightMargin wider than the left to leave room for dismissButton
        // in the corner, same as NotificationHistoryPane's entries.
        anchors { leftMargin: 12; rightMargin: 22 }
        spacing: 10

        IconImage {
            id: icon
            anchors.verticalCenter: parent.verticalCenter
            visible: bubble.iconSource !== ""
            implicitSize: 32
            source: bubble.iconSource
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: content.width - (icon.visible ? icon.width + content.spacing : 0)
            spacing: 2

            Text {
                width: parent.width
                text: bubble.notification?.summary ?? ""
                color: Theme.colFg
                font { family: Theme.fontFamily; pixelSize: Theme.fontSize; bold: true }
                elide: Text.ElideRight
            }

            Text {
                width: parent.width
                visible: text !== ""
                text: bubble.notification?.body ?? ""
                color: Theme.colMuted
                font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 2 }
                wrapMode: Text.Wrap
                maximumLineCount: 6
                elide: Text.ElideRight
            }
        }
    }

    HoverHandler { id: hover }

    MouseArea {
        // Click anywhere on the bubble to dismiss early, same as every
        // other notification daemon. MouseArea rather than TapHandler:
        // inside a Repeater delegate, TapHandler's tap recognition was
        // observed (on NotificationHistoryPane's dismiss button) to eat
        // clicks entirely - hover still worked, onTapped never fired.
        anchors.fill: parent
        onClicked: bubble.notification.dismiss()
    }

    // Explicit dismiss button, same corner/style as NotificationHistoryPane's
    // entries - declared after (so on top of) the whole-bubble MouseArea
    // above, so a click here takes priority over the general dismiss-anywhere
    // behavior rather than double-firing it.
    Item {
        anchors { right: parent.right; top: parent.top; margins: 2 }
        width: 20
        height: 20

        Text {
            anchors.centerIn: parent
            text: "×"
            color: dismissArea.containsMouse ? Theme.colRed : Theme.colMuted
            font { family: Theme.fontFamily; pixelSize: Theme.fontSize + 2 }
        }

        MouseArea {
            id: dismissArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: bubble.notification.dismiss()
        }
    }

    Timer {
        interval: bubble.effectiveTimeout
        // Restarts from the full interval on mouse-leave rather than
        // resuming the exact remaining time - simpler, and close enough for
        // a "don't vanish while I'm reading it" pause.
        running: bubble.effectiveTimeout > 0 && !hover.hovered
        onTriggered: bubble.notification.expire()
    }
}
