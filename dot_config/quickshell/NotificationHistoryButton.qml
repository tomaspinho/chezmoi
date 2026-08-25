import QtQuick

// Bar icon only - the actual history list lives in NotificationHistoryPane's
// own full-height surface (it needs to slide out over everything, which a
// bar-anchored popup can't do), so this just reflects that pane's state and
// asks it to toggle.
Item {
    id: bell

    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colBlue: "#7aa2f7"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14

    // Whether NotificationHistoryPane is currently open, and how many
    // entries it has - both owned there, mirrored here just for the glyph.
    required property bool open
    required property int historyCount

    signal toggleRequested()

    implicitWidth: icon.implicitWidth + 8
    implicitHeight: icon.implicitHeight

    Text {
        id: icon
        anchors.centerIn: parent
        // md-bell / md-bell_outline: solid once there's something to show,
        // same idea as ProcessToggle's on/off glyph pair, doubling as a
        // "there's history" indicator without a separate unread badge.
        text: String.fromCodePoint(bell.historyCount > 0 ? 0xF009A : 0xF009C)
        color: bell.open ? bell.colBlue : bell.colFg
        font { family: bell.fontFamily; pixelSize: bell.fontSize }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: bell.toggleRequested()
    }
}
