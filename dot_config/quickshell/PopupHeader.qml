import QtQuick

// The title row at the top of the Wi-Fi and Bluetooth popups: a name on the
// left, and the adapter's on/off state on the right doubling as the toggle.
Item {
    id: header

    property string title: ""
    property bool on: false
    // Wi-Fi prefixes its labels with a glyph, Bluetooth doesn't, so the text
    // is passed in whole rather than assembled here.
    property string onLabel: "on"
    property string offLabel: "off"
    property bool bold: false
    // Whether the state is actually clickable - a missing adapter or a
    // hardware rfkill leaves it readable but inert.
    property bool toggleEnabled: true

    signal toggled()

    width: parent ? parent.width : 0
    height: 24

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: header.title
        color: Theme.colFg
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize; bold: header.bold }
    }

    Text {
        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
        text: header.on ? header.onLabel : header.offLabel
        color: header.on ? Theme.colCyan : Theme.colMuted
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 2 }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: header.toggleEnabled
            onClicked: header.toggled()
        }
    }
}
