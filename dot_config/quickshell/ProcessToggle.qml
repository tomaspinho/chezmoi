import Quickshell
import Quickshell.Io
import QtQuick

// Click to kill a running process, click again to start it back up. Mirrors
// what waybar's toggle_process.sh did, with pgrep -x for the state check.
Item {
    id: toggle

    property color colOn: "#0db9d7"
    property color colOff: "#444b6a"

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

    // Catch changes made outside the bar - the process dying on its own, or
    // being started/killed from a terminal. Deliberately slow: this spawns a
    // pgrep every tick, forever, on every instance of this widget, and the
    // changes it exists to notice are rare and not urgent. Anything the user
    // does *here* is already reflected within 250ms by `settle` above, so this
    // interval only bounds how long a stale reading can survive, not how
    // responsive a click feels.
    Timer {
        interval: 15000
        running: true
        repeat: true
        onTriggered: toggle.refresh()
    }

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    BarIcon {
        id: icon
        anchors.centerIn: parent
        glyph: String.fromCodePoint(toggle.running ? toggle.glyphOn : toggle.glyphOff)
        color: toggle.running ? toggle.colOn : toggle.colOff
        // +4: same as the wifi icon - both the nightlight and idle-manager
        // glyphs are drawn small/thin within their cell next to bar icons
        // like bluetooth, so they read as noticeably smaller at the same
        // pixelSize.
        oversize: 4
        // the glyphs are narrow, so pad out the click target
        padding: 8
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggleProcess()
    }
}
