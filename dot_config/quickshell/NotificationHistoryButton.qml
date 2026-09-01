import QtQuick

// Bar icon only - the actual history list lives in NotificationHistoryPane's
// own full-height surface (it needs to slide out over everything, which a
// bar-anchored popup can't do), so this just reflects that pane's state and
// asks it to toggle.
Item {
    id: bell


    // Whether NotificationHistoryPane is currently open, and how many
    // entries it has - both owned there, mirrored here just for the glyph.
    required property bool open
    required property int historyCount

    signal toggleRequested()

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    BarIcon {
        id: icon
        anchors.centerIn: parent
        // md-bell / md-bell_outline: solid once there's something to show,
        // same idea as ProcessToggle's on/off glyph pair, doubling as a
        // "there's history" indicator without a separate unread badge.
        glyph: String.fromCodePoint(bell.historyCount > 0 ? 0xF009A : 0xF009C)
        color: bell.open ? Theme.colBlue : Theme.colFg
        // the bell is narrow, so pad out the click target
        padding: 8
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: bell.toggleRequested()
    }
}
