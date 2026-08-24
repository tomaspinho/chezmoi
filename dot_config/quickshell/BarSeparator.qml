import QtQuick

// A vertical dotted rule for separating bar widgets.
//
// Qt has no dashed/dotted border primitive for a 1px line (Rectangle borders are
// solid, and Canvas setLineDash would mean a full scene-graph texture per rule),
// so the dots are laid out explicitly as a Column of small squares.
//
// Sizes are deliberately coarse rather than snapped to the physical pixel grid.
// Snapping isn't achievable here: Qt reports Screen.devicePixelRatio 2 for this
// display while the output is really scaled 1.25, so Qt renders into a 2x buffer
// that the compositor then *downscales*. 1/devicePixelRatio is therefore not a
// physical pixel, and a hairline pattern built from it aliases unpredictably —
// dots merge or drop out entirely. Anything about 2px and up survives intact.
Item {
    id: sep

    property color color: "#444b6a"
    property int dotSize: 2
    property int dotGap: 2

    readonly property int period: dotSize + dotGap

    // n dots occupy n*period - dotGap, since the last period's trailing gap is
    // not drawn. Fit a whole number so the pattern never clips mid-dot.
    readonly property int dotCount:
        Math.max(1, Math.floor((height + dotGap) / period))

    implicitWidth: dotSize

    // Kept within the bar's content height so the rules never dictate how tall
    // the panel has to be. 3*4 - 2 = 10 divides the pattern exactly, so there
    // is no leftover slack to distribute.
    implicitHeight: 10

    Column {
        anchors.centerIn: parent
        spacing: sep.dotGap

        Repeater {
            model: sep.dotCount

            Rectangle {
                width: sep.dotSize
                height: sep.dotSize
                color: sep.color
            }
        }
    }
}
