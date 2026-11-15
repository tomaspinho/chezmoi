import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.UPower
import QtQuick

Item {
    id: bat

    // UPower's aggregate battery. Like Networking, it isn't ready for a few
    // seconds after startup, so these stay live bindings.
    readonly property var device: UPower.displayDevice

    readonly property bool available: (device?.ready ?? false)
        && (device?.isPresent ?? false)
        && (device?.isLaptopBattery ?? false)

    // percentage comes through as a 0-1 fraction
    readonly property int percent: Math.round((device?.percentage ?? 0) * 100)

    readonly property bool charging: device?.state === UPowerDeviceState.Charging
        || device?.state === UPowerDeviceState.PendingCharge
    readonly property bool full: device?.state === UPowerDeviceState.FullyCharged

    // 0% -> 100% in 10% steps. The per-level *charging* glyphs are unreliable in
    // this font (F08A0 is a bed, F08A1+ are missing), so charging just gets the
    // one bolt glyph and the level is read off the percentage.
    readonly property var levels: ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

    readonly property color tint: charging || full ? Theme.colGreen
        : percent <= 15 ? Theme.colRed
        : percent <= 30 ? Theme.colYellow
        : Theme.colFg

    // ---- CPU scaling governor ------------------------------------------
    // Shown in the popover under the battery icon. The sysfs governor files
    // are root-owned, so applying a choice goes through pkexec and the
    // session's polkit agent prompts for it. Reads are a plain cat.

    property bool expanded: false

    // one entry per word in scaling_available_governors
    property var governors: []
    property string governor: ""
    property string governorError: ""

    // blocks a second choice while pkexec is still up (or still prompting)
    property bool governorBusy: false

    function refreshGovernor() {
        if (!governorRead.running) governorRead.running = true;
    }

    function setGovernor(name) {
        if (governorBusy || name === governor) return;
        governorError = "";
        governorBusy = true;
        // Every policy, not just policy0: intel_pstate keeps one governor per
        // policy and `cpupower frequency-set` does the same walk. Passing the
        // name as a positional argument keeps it out of the shell text.
        governorSet.command = [
            "pkexec", "sh", "-c",
            "for f in /sys/devices/system/cpu/cpufreq/policy*/scaling_governor;"
                + " do echo \"$1\" > \"$f\" || exit 1; done",
            "sh", name
        ];
        governorSet.running = true;
    }

    Process {
        id: governorList
        command: ["cat", "/sys/devices/system/cpu/cpufreq/policy0/scaling_available_governors"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: bat.governors = text.trim().split(/\s+/).filter(Boolean)
        }
    }

    Process {
        id: governorRead
        // policy0 represents the whole package: the write below keeps every
        // policy on the same value, and nothing changes them independently.
        command: ["cat", "/sys/devices/system/cpu/cpufreq/policy0/scaling_governor"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: bat.governor = text.trim()
        }
    }

    Process {
        id: governorSet
        command: ["true"]
        stderr: StdioCollector { id: governorSetErr }

        onExited: exitCode => {
            bat.governorBusy = false;
            if (exitCode === 0) {
                bat.refreshGovernor();
                // The polkit prompt takes focus and clears the focus grab, so
                // the popup is already gone by now; bring it back so the tick
                // moves visibly instead of the click looking like a no-op.
                bat.expanded = true;
                return;
            }
            // 126/127 are pkexec's "dismissed" and "not authorized" codes, and
            // it prints nothing on stderr for either.
            const detail = governorSetErr.text.trim().split("\n").pop();
            bat.governorError = detail !== "" ? detail
                : exitCode === 126 ? "Authentication cancelled"
                : exitCode === 127 ? "Not authorized"
                : `exited ${exitCode}`;
            bat.expanded = true; // bring the popup back to show the error
        }
    }

    // Catch a governor changed outside the bar (a terminal, a profile daemon)
    // while the popup is open. Nothing on the bar itself shows the governor, so
    // polling while closed would only spawn cat for nobody to read.
    Timer {
        interval: 2000
        running: bat.expanded
        repeat: true
        onTriggered: bat.refreshGovernor()
    }

    // hidden on machines with no battery
    visible: available

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: bat.charging ? "󰂄" : bat.levels[Math.round(bat.percent / 10)]
            color: bat.tint
            font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: `${bat.percent}%`
            color: bat.tint
            font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            bat.expanded = !bat.expanded;
            if (bat.expanded) {
                bat.refreshGovernor();
                // cpufreq can arrive after startup (module load, late probe),
                // leaving the one-shot read at the top with an empty list.
                if (bat.governors.length === 0 && !governorList.running)
                    governorList.running = true;
            } else {
                bat.governorError = "";
            }
        }
    }

    HyprlandFocusGrab {
        active: bat.expanded
        windows: [governorPopup]
        onCleared: bat.expanded = false
    }

    BarPopup {
        id: governorPopup
        anchorItem: bat
        visible: bat.expanded
        popupWidth: 192
        contentMargin: 6
        contentPadding: 12
        spacing: 1

        Item {
            width: parent.width
            height: 24

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "CPU governor"
                color: Theme.colFg
                font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
            }

            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                text: bat.governor || "—"
                color: Theme.colCyan
                font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 2 }
            }
        }

        PopupDivider {}

        Text {
            width: parent.width
            visible: bat.governors.length === 0
            padding: 4
            text: "No cpufreq interface"
            color: Theme.colMuted
            font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 2 }
        }

        Repeater {
            model: bat.governors

            Rectangle {
                required property string modelData

                readonly property bool selected: modelData === bat.governor

                width: parent.width
                height: 26
                radius: 4
                color: hover.hovered && !bat.governorBusy
                    ? Qt.lighter(Theme.colBg, 1.6) : "transparent"
                // while prompting, everything but the row being applied fades
                opacity: bat.governorBusy && !selected ? 0.5 : 1

                Text {
                    anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                    text: modelData
                    color: modelData === bat.governor ? Theme.colCyan : Theme.colFg
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 2 }
                }

                Text {
                    anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                    text: bat.governorBusy && selected ? "…"
                        : selected ? "󰄬" : ""
                    color: bat.governorBusy ? Theme.colMuted : Theme.colCyan
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 2 }
                }

                HoverHandler {
                    id: hover
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    onTapped: bat.setGovernor(modelData)
                }
            }
        }

        Text {
            width: parent.width
            visible: bat.governorError !== ""
            padding: 4
            text: bat.governorError
            wrapMode: Text.Wrap
            color: Theme.colRed
            font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 4 }
        }
    }
}
