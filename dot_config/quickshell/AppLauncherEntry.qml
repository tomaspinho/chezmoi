import Quickshell
import Quickshell.Widgets
import QtQuick

// One row in the launcher list - either an application itself, or (when its
// parent app is expanded) one of that app's Desktop Actions ("New Window",
// "New Private Window", ...) indented beneath it. Purely presentational:
// AppLauncher.qml owns selection/expansion state and just tells each row
// whether it's the current one.
Rectangle {
    id: row

    // { kind: "app"|"action", entry: DesktopEntry, action: DesktopAction|null, key }
    required property var itemData
    // Keyboard-selected *or* mouse-hovered row - both drive the same
    // highlight, since they're really the same "current row" concept.
    property bool active: false
    // Whether entry.actions is currently expanded beneath this row. Passed
    // in rather than recomputed here because "which app is expanded" is
    // list-wide state, not something a single row can know on its own.
    property bool expanded: false

    property color colBg: "#1a1b26"
    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colBlue: "#7aa2f7"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14

    signal activate()
    signal expandToggle()
    signal hoverEntered()

    readonly property bool isAction: itemData.kind === "action"
    readonly property var entry: itemData.entry
    readonly property string label: isAction ? itemData.action.name : entry.name
    readonly property string iconName: isAction && itemData.action.icon !== ""
        ? itemData.action.icon : entry.icon
    // Actions of an action row don't themselves expand - only top-level apps
    // with their own actions do.
    readonly property bool expandable: !isAction && entry.actions.length > 0

    height: 36
    radius: 4
    color: row.active ? Qt.lighter(row.colBg, 1.8) : "transparent"

    IconImage {
        id: icon
        anchors { left: parent.left; leftMargin: row.isAction ? 40 : 10; verticalCenter: parent.verticalCenter }
        implicitSize: 22
        source: row.iconName !== "" ? Quickshell.iconPath(row.iconName, "") : ""
    }

    Text {
        anchors {
            left: icon.right; leftMargin: 10
            right: chevron.visible ? chevron.left : parent.right
            rightMargin: 10
            verticalCenter: parent.verticalCenter
        }
        text: row.label
        color: row.colFg
        font { family: row.fontFamily; pixelSize: row.fontSize }
        elide: Text.ElideRight
    }

    Text {
        id: chevron
        anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
        visible: row.expandable
        // Material "chevron-right"/"chevron-down" - collapsed points at the
        // row, expanded points down at the actions it revealed.
        text: String.fromCodePoint(row.expanded ? 0xF0140 : 0xF0142)
        color: row.colMuted
        font { family: row.fontFamily; pixelSize: row.fontSize - 2 }
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onEntered: row.hoverEntered()
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                if (row.expandable) row.expandToggle();
            } else {
                row.activate();
            }
        }
    }
}
