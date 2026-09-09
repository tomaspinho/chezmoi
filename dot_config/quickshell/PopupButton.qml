import QtQuick

// The full-width outlined button at the bottom of a popup, used to hand off to
// a real application for everything the popup itself doesn't cover
// (nm-connection-editor, pavucontrol).
//
// The caller keeps the launch itself: both current uses go through
// Hyprland.dispatch rather than execDetached so a one-shot [float] rule
// applies, which is a decision about the command, not about the button.
Rectangle {
    id: button

    property string text: ""

    signal clicked()

    width: parent ? parent.width : 0
    height: 24
    radius: 4
    color: hover.hovered ? Qt.lighter(Theme.colBg, 1.8) : "transparent"
    border { width: 1; color: Theme.colMuted }

    Text {
        anchors.centerIn: parent
        text: button.text
        color: hover.hovered ? Theme.colCyan : Theme.colFg
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 3 }
    }

    HoverHandler {
        id: hover
        // Not on the TapHandler: a pointer handler's cursorShape only applies
        // while it is active, which for a tap is "while held", not "while
        // hovered". This is the one surviving copy of a note that used to be
        // pasted at five separate call sites.
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: button.clicked()
    }
}
