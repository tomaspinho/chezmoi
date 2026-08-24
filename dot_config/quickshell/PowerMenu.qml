import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Item {
    id: pwr

    property color colBg: "#1a1b26"
    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colRed: "#f7768e"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14

    property bool expanded: false

    // Set when a command exits nonzero, so a refused or unsupported action
    // (polkit denial, hibernate with no resume device) isn't silent.
    property string error: ""

    // Ordered least to most destructive. `shutdown` with no time argument is
    // systemd's "+1", i.e. one minute out - `shutdown -c` cancels it.
    readonly property var actions: [
        { label: "Lock", glyph: 0xF033E, danger: false, command: ["loginctl", "lock-session"] },
        { label: "Suspend", glyph: 0xF04B2, danger: false, command: ["systemctl", "suspend"] },
        { label: "Hibernate", glyph: 0xF0594, danger: false, command: ["systemctl", "hibernate"] },
        { label: "Reboot", glyph: 0xF0709, danger: true, command: ["reboot"] },
        { label: "Shut down", glyph: 0xF0425, danger: true, command: ["shutdown"] }
    ]

    function run(command) {
        error = "";
        runner.command = command;
        runner.running = true;
        expanded = false;
    }

    Process {
        id: runner
        command: ["true"]
        stderr: StdioCollector { id: runnerErr }

        onExited: exitCode => {
            if (exitCode === 0) return;
            const detail = runnerErr.text.trim().split("\n").pop();
            pwr.error = detail !== "" ? detail : `exited ${exitCode}`;
            pwr.expanded = true; // bring the menu back to show what went wrong
        }
    }

    // the power glyph is narrow, so pad out the click target
    implicitWidth: icon.implicitWidth + 8
    implicitHeight: icon.implicitHeight

    Text {
        id: icon
        anchors.centerIn: parent
        text: String.fromCodePoint(0xF0425)
        color: pwr.expanded ? pwr.colRed : pwr.colFg
        font { family: pwr.fontFamily; pixelSize: pwr.fontSize }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            pwr.expanded = !pwr.expanded;
            if (!pwr.expanded) pwr.error = "";
        }
    }

    HyprlandFocusGrab {
        active: pwr.expanded
        windows: [menu]
        onCleared: pwr.expanded = false
    }

    PopupWindow {
        id: menu

        anchor {
            item: pwr
            edges: Edges.Bottom
            gravity: Edges.Bottom | Edges.Left
            margins.top: 6
        }

        color: "transparent"
        visible: pwr.expanded
        implicitWidth: 172
        implicitHeight: frame.implicitHeight

        Rectangle {
            id: frame
            anchors.fill: parent
            implicitHeight: column.implicitHeight + 12
            color: pwr.colBg
            radius: 8
            border { width: 1; color: pwr.colMuted }

            Column {
                id: column
                anchors { fill: parent; margins: 6 }
                spacing: 1

                Repeater {
                    model: pwr.actions

                    Rectangle {
                        required property var modelData

                        width: parent.width
                        height: 26
                        radius: 4
                        color: hover.hovered
                            ? (modelData.danger ? Qt.darker(pwr.colRed, 3.2) : Qt.lighter(pwr.colBg, 1.8))
                            : "transparent"

                        Text {
                            id: rowGlyph
                            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                            text: String.fromCodePoint(modelData.glyph)
                            color: modelData.danger ? pwr.colRed : pwr.colFg
                            font { family: pwr.fontFamily; pixelSize: pwr.fontSize }
                        }

                        Text {
                            anchors { left: rowGlyph.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                            text: modelData.label
                            color: hover.hovered && modelData.danger ? pwr.colRed : pwr.colFg
                            font { family: pwr.fontFamily; pixelSize: pwr.fontSize - 2 }
                        }

                        HoverHandler { id: hover }

                        TapHandler {
                            onTapped: pwr.run(modelData.command)
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: pwr.error !== ""
                    padding: 4
                    text: pwr.error
                    wrapMode: Text.Wrap
                    color: pwr.colRed
                    font { family: pwr.fontFamily; pixelSize: pwr.fontSize - 4 }
                }
            }
        }
    }
}
