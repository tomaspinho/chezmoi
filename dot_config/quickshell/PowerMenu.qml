import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Item {
    id: pwr


    property bool expanded: false

    // Set when a command exits nonzero, so a refused or unsupported action
    // (polkit denial, hibernate with no resume device) isn't silent.
    property string error: ""

    // Ordered least to most destructive. All five act immediately: bare
    // `shutdown` would instead schedule systemd's "+1" (a minute out,
    // cancellable only with `shutdown -c` from a terminal), which this menu
    // gives no indication of and no way to call off - and which made "Shut
    // down" behave unlike "Reboot" right next to it.
    readonly property var actions: [
        { label: "Lock", glyph: 0xF033E, danger: false, command: ["loginctl", "lock-session"] },
        { label: "Suspend", glyph: 0xF04B2, danger: false, command: ["systemctl", "suspend"] },
        { label: "Hibernate", glyph: 0xF0594, danger: false, command: ["systemctl", "hibernate"] },
        { label: "Reboot", glyph: 0xF0709, danger: true, command: ["systemctl", "reboot"] },
        { label: "Shut down", glyph: 0xF0425, danger: true, command: ["systemctl", "poweroff"] }
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

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    BarIcon {
        id: icon
        anchors.centerIn: parent
        glyph: String.fromCodePoint(0xF0425)
        color: pwr.expanded ? Theme.colRed : Theme.colFg
        // the power glyph is narrow, so pad out the click target
        padding: 8
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

    BarPopup {
        id: menu
        anchorItem: pwr
        visible: pwr.expanded
        popupWidth: 172
        contentMargin: 6
        contentPadding: 12
        spacing: 1

        Repeater {
            model: pwr.actions

            Rectangle {
                required property var modelData

                width: parent.width
                height: 26
                radius: 4
                color: hover.hovered
                    ? (modelData.danger ? Qt.darker(Theme.colRed, 3.2) : Qt.lighter(Theme.colBg, 1.8))
                    : "transparent"

                Text {
                    id: rowGlyph
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    text: String.fromCodePoint(modelData.glyph)
                    color: modelData.danger ? Theme.colRed : Theme.colFg
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
                }

                Text {
                    anchors { left: rowGlyph.right; leftMargin: 10; verticalCenter: parent.verticalCenter }
                    text: modelData.label
                    color: hover.hovered && modelData.danger ? Theme.colRed : Theme.colFg
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 2 }
                }

                HoverHandler {
                    id: hover
                    // Not on the TapHandler: a pointer handler's
                    // cursorShape only applies while it is active,
                    // which for a tap is "while held", not "while
                    // hovered".
                    cursorShape: Qt.PointingHandCursor
                }

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
            color: Theme.colRed
            font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 4 }
        }
    }
}
