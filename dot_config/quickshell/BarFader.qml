import QtQuick

// Glyph, groove-and-handle slider, and a right-aligned percentage - the
// control inside both the volume and brightness popups, which were previously
// two ~80-line copies of each other.
//
// Purely an input surface: it reports where the user dragged or scrolled to
// and renders whatever `percent` it is given back. Clamping, muting, the
// brightness floor and brightnessctl's write debouncing all stay with the
// widget that owns them.
Item {
    id: fader

    property int glyph: 0
    property color accent: Theme.colCyan
    property int percent: 0
    property bool ready: true
    // 0-1, drives the fill and handle. Kept separate from `percent` because
    // volume's underlying value can exceed 1 (over-amplification) while the
    // track still stops at full.
    property real fraction: 0

    // Absolute position, 0-1 along the track.
    signal moved(real position)
    // One wheel notch; +1 is "increase".
    signal stepped(int direction)
    // Drag finished - brightness uses this to reconcile against brightnessctl.
    signal released()

    implicitHeight: 22

    Text {
        id: faderIcon
        anchors { left: parent.left; leftMargin: 2; verticalCenter: parent.verticalCenter }
        text: String.fromCodePoint(fader.glyph)
        color: fader.accent
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
    }

    Text {
        id: faderLabel
        anchors { right: parent.right; rightMargin: 2; verticalCenter: parent.verticalCenter }
        // fixed width so the track doesn't resize as the number grows
        width: 38
        horizontalAlignment: Text.AlignRight
        text: fader.ready ? `${fader.percent}%` : "--"
        color: Theme.colFg
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 1 }
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
            color: Theme.colMuted

            Rectangle {
                width: groove.width * fader.fraction
                height: parent.height
                radius: parent.radius
                color: fader.accent
            }
        }

        Rectangle {
            id: handle
            width: 13
            height: 13
            radius: width / 2
            color: fader.accent
            anchors.verticalCenter: parent.verticalCenter
            x: Math.max(0, Math.min(track.width - width,
                fader.fraction * track.width - width / 2))
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            preventStealing: true

            function apply(x) {
                fader.moved(Math.max(0, Math.min(1, x / width)));
            }

            onPressed: mouse => apply(mouse.x)
            onPositionChanged: mouse => { if (pressed) apply(mouse.x); }
            onReleased: fader.released()
            // Positive delta increases. The widget's bar icon must use this
            // same sign, or its two surfaces move the value opposite ways.
            onWheel: wheel => fader.stepped(wheel.angleDelta.y > 0 ? 1 : -1)
        }
    }
}
