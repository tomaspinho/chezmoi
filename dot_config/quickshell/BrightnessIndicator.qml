import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Item {
    id: br


    property bool expanded: false

    // true while the fader handle is being dragged
    property bool dragging: false

    // Floor rather than 0, since a fully dark backlight is indistinguishable
    // from a broken screen and awkward to recover from.
    property int minPercent: 1

    // -1 until the first brightnessctl read lands
    property int percent: -1
    readonly property bool ready: percent >= 0

    // False until proven otherwise: some machines (this desktop, driving its
    // monitor over DisplayPort) have no backlight-class device at all, so
    // brightnessctl would otherwise fall back to whatever it finds first —
    // e.g. a keyboard LED — and report that as if it were display
    // brightness. -c backlight below keeps parseInfo from ever seeing those,
    // so a successful read here means a real, controllable backlight exists.
    readonly property bool available: ready

    // The md brightness-1..7 block isn't a usable ramp in this font (it mixes
    // moons, contrast circles and an auto-brightness glyph), so this is just a
    // dim sun and a bright sun. The percentage carries the detail.
    readonly property int dimSun: 0xF00DE
    readonly property int brightSun: 0xF0599

    // Reading back mid-drag would fight the value the user is dragging to.
    function refresh() {
        if (dragging || pending >= 0) return;
        if (!readProc.running) readProc.running = true;
    }

    // brightnessctl -m info -> "intel_backlight,backlight,1939,10%,19393"
    function parseInfo(text) {
        for (const line of text.trim().split("\n")) {
            const f = line.split(",");
            if (f.length < 5) continue;
            const cur = parseInt(f[2]);
            const max = parseInt(f[4]);
            if (!isFinite(cur) || !isFinite(max) || max <= 0) continue;
            percent = Math.max(0, Math.min(100, Math.round((cur / max) * 100)));
            return;
        }
    }

    // One percentage point per wheel notch; reads back from brightnessctl
    // after. Both call sites (the bar icon and the fader track) must pass the
    // same sign for a given scroll direction, or the two surfaces of this one
    // widget move the backlight opposite ways.
    function step(direction) {
        if (!ready) return;
        const next = Math.max(minPercent, Math.min(100, percent + direction));
        if (next === percent) return;
        percent = next; // optimistic; reconciled by the read below
        pending = next;
        debounce.restart();
    }

    // Fader drag: any value, not just the 10% scroll grid.
    function setTo(value) {
        const next = Math.max(minPercent, Math.min(100, Math.round(value)));
        if (next === percent) return;
        percent = next; // optimistic; reconciled once brightnessctl exits
        pending = next;
        debounce.restart();
    }

    property int pending: -1

    readonly property real fraction: ready ? percent / 100 : 0

    Process {
        id: readProc
        // -c backlight: without it brightnessctl picks a "default" device
        // that can be a keyboard LED, not the display backlight.
        command: ["brightnessctl", "-m", "-c", "backlight", "info"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: br.parseInfo(text)
        }
    }

    Process {
        id: setProc
        command: ["brightnessctl", "-m", "-c", "backlight", "set", "50%"]
        onExited: br.refresh()
    }

    // A trackpad emits a burst of wheel events; coalesce them into one call.
    Timer {
        id: debounce
        interval: 60
        onTriggered: {
            if (br.pending < 0) return;
            setProc.command = ["brightnessctl", "-m", "-c", "backlight", "set", `${br.pending}%`];
            setProc.running = true;
            br.pending = -1;
        }
    }

    // brightnessctl has no change signal, but the kernel emits a udev change
    // event on the backlight device for every write, whoever made it — the
    // XF86MonBrightness keys, hypridle dimming, another shell instance. That
    // makes this as live as the pipewire-backed volume widget, instead of
    // lagging up to one poll interval behind the keyboard.
    Process {
        id: monitorProc
        // udevadm line-buffers to a pipe, so no stdbuf dance is needed.
        command: ["udevadm", "monitor", "--udev", "--subsystem-match=backlight"]
        running: true
        stdout: SplitParser {
            // Skips the "monitor will print..." preamble; every event line
            // starts with the source tag.
            onRead: line => { if (line.startsWith("UDEV")) coalesce.restart(); }
        }
        // Nothing restarts a dead Process on its own, and without the delay a
        // missing udevadm would spin here.
        onExited: monitorRetry.restart()
    }

    // Holding a brightness key emits a burst of events; one read back is enough.
    Timer {
        id: coalesce
        interval: 50
        onTriggered: br.refresh()
    }

    Timer {
        id: monitorRetry
        interval: 2000
        onTriggered: monitorProc.running = true
    }

    // Backstop for the monitor being unavailable rather than merely idle (no
    // udevadm on the system, netlink refused), so the readout can't sit stale
    // forever. Silent while the monitor is alive.
    Timer {
        interval: 3000
        running: !monitorProc.running
        repeat: true
        onTriggered: br.refresh()
    }

    // hidden on machines with no controllable backlight (e.g. a desktop
    // driving a DisplayPort monitor)
    visible: available

    implicitWidth: content.implicitWidth
    implicitHeight: content.implicitHeight

    Row {
        id: content
        anchors.centerIn: parent
        spacing: 5

        Text {
            text: String.fromCodePoint(br.percent > 40 ? br.brightSun : br.dimSun)
            color: br.ready ? Theme.colYellow : Theme.colMuted
            font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
        }

        Text {
            text: br.ready ? `${br.percent}%` : "--"
            color: br.ready ? Theme.colFg : Theme.colMuted
            font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        // Positive delta brightens, matching the fader track's own wheel
        // handler below. See VolumeIndicator's note on why the physical
        // direction differs between the touchpad and a mouse.
        onWheel: wheel => br.step(wheel.angleDelta.y > 0 ? 1 : -1)
        onClicked: br.expanded = !br.expanded
    }

    HyprlandFocusGrab {
        active: br.expanded
        windows: [fader]
        onCleared: br.expanded = false
    }

    BarPopup {
        id: fader
        anchorItem: br
        visible: br.expanded
        popupWidth: 240
        contentMargin: 10
        // The fader is 22 high, so this reproduces the 44 the frame used to
        // hard-code before the popup chrome was shared.
        contentPadding: 22

        BarFader {
            width: parent.width
            glyph: br.percent > 40 ? br.brightSun : br.dimSun
            accent: Theme.colYellow
            percent: br.percent
            ready: br.ready
            fraction: br.fraction

            // `dragging` gates refresh() so a read-back can't fight the value
            // being dragged to; it stays set from the first press until the
            // release below.
            onMoved: position => {
                br.dragging = true;
                br.setTo(position * 100);
            }
            onStepped: direction => br.step(direction)
            onReleased: {
                br.dragging = false;
                br.refresh();
            }
        }
    }
}
