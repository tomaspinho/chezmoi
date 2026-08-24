import Quickshell
import Quickshell.Io
import QtQuick

// Click to kill a running process, click again to start it back up. Mirrors
// what waybar's toggle_process.sh did, with pgrep -x for the state check.
Item {
    id: toggle

    property color colOn: "#0db9d7"
    property color colOff: "#444b6a"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14

    // process to manage, e.g. "hyprsunset"
    required property string processName

    // both are started bare, exactly as hyprland's exec-once does
    property var startCommand: [processName]

    required property int glyphOn
    required property int glyphOff

    property bool running: false

    // blocks a second click while a kill/start is still settling
    property bool busy: false

    function refresh() {
        if (!probe.running) probe.running = true;
    }

    function toggleProcess() {
        if (busy) return;
        busy = true;
        if (running) {
            killer.running = true;
        } else {
            // detached so it outlives a shell reload, like exec-once does
            Quickshell.execDetached(startCommand);
            settle.restart();
        }
    }

    Process {
        id: probe
        command: ["pgrep", "-x", toggle.processName]
        running: true
        onExited: exitCode => toggle.running = exitCode === 0
    }

    Process {
        id: killer
        command: ["pkill", "-x", toggle.processName]
        onExited: settle.restart()
    }

    // give the process a moment to actually appear/disappear before re-probing
    Timer {
        id: settle
        interval: 250
        onTriggered: {
            toggle.busy = false;
            toggle.refresh();
        }
    }

    // catch changes made outside the bar
    Timer {
        interval: 3000
        running: true
        repeat: true
        onTriggered: toggle.refresh()
    }

    // the glyphs are narrow, so pad out the click target
    implicitWidth: icon.implicitWidth + 8
    implicitHeight: icon.implicitHeight

    Text {
        id: icon
        anchors.centerIn: parent
        text: String.fromCodePoint(toggle.running ? toggle.glyphOn : toggle.glyphOff)
        color: toggle.running ? toggle.colOn : toggle.colOff
        font { family: toggle.fontFamily; pixelSize: toggle.fontSize }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggleProcess()
    }
}
