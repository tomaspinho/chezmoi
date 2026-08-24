import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import QtQuick

Item {
    id: br

    property color colBg: "#1a1b26"
    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colYellow: "#e0af68"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14

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

    // Snap to the 10% grid, then step. Reads back from brightnessctl after.
    function step(direction) {
        if (!ready) return;
        const base = percent;
        const next = Math.max(minPercent, Math.min(100, base + direction));
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

    // brightnessctl has no change signal, so pick up the keyboard keys by polling
    Timer {
        interval: 3000
        running: true
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
            color: br.ready ? br.colYellow : br.colMuted
            font { family: br.fontFamily; pixelSize: br.fontSize }
        }

        Text {
            text: br.ready ? `${br.percent}%` : "--"
            color: br.ready ? br.colFg : br.colMuted
            font { family: br.fontFamily; pixelSize: br.fontSize }
        }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onWheel: wheel => br.step(wheel.angleDelta.y > 0 ? -1 : 1)
        onClicked: br.expanded = !br.expanded
    }

    HyprlandFocusGrab {
        active: br.expanded
        windows: [fader]
        onCleared: br.expanded = false
    }

    PopupWindow {
        id: fader

        anchor {
            item: br
            edges: Edges.Bottom
            gravity: Edges.Bottom | Edges.Left
            margins.top: 6
        }

        color: "transparent"
        visible: br.expanded
        implicitWidth: 240
        implicitHeight: frame.implicitHeight

        Rectangle {
            id: frame
            anchors.fill: parent
            implicitHeight: 44
            color: br.colBg
            radius: 8
            border { width: 1; color: br.colMuted }

            Text {
                id: faderIcon
                anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                text: String.fromCodePoint(br.percent > 40 ? br.brightSun : br.dimSun)
                color: br.colYellow
                font { family: br.fontFamily; pixelSize: br.fontSize + 1 }
            }

            Text {
                id: faderLabel
                anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                // fixed width so the track doesn't resize as the number grows
                width: 38
                horizontalAlignment: Text.AlignRight
                text: br.ready ? `${br.percent}%` : "--"
                color: br.colFg
                font { family: br.fontFamily; pixelSize: br.fontSize - 1 }
            }

            Item {
                id: track

                anchors {
                    left: faderIcon.right; leftMargin: 10
                    right: faderLabel.left; rightMargin: 8
                    verticalCenter: parent.verticalCenter
                }
                height: 20

                Rectangle {
                    id: groove
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: 6
                    radius: 3
                    color: br.colMuted

                    Rectangle {
                        width: groove.width * br.fraction
                        height: parent.height
                        radius: parent.radius
                        color: br.colYellow
                    }
                }

                Rectangle {
                    id: handle
                    width: 13
                    height: 13
                    radius: width / 2
                    color: br.colYellow
                    anchors.verticalCenter: parent.verticalCenter
                    x: Math.max(0, Math.min(track.width - width,
                        br.fraction * track.width - width / 2))
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    preventStealing: true

                    function apply(x) {
                        br.setTo(Math.max(0, Math.min(1, x / width)) * 100);
                    }

                    onPressed: mouse => {
                        br.dragging = true;
                        apply(mouse.x);
                    }
                    onPositionChanged: mouse => {
                        if (pressed) apply(mouse.x);
                    }
                    onReleased: {
                        br.dragging = false;
                        br.refresh();
                    }
                    onWheel: wheel => br.step(wheel.angleDelta.y > 0 ? 1 : -1)
                }
            }
        }
    }
}
