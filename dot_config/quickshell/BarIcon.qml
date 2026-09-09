import QtQuick

// A single Nerd Font glyph on the bar, plus the two bits of sizing fiddliness
// every bar icon needs.
//
// `oversize` compensates for glyphs that are drawn small within their own cell
// (the Wi-Fi bars, the nightlight/idle pair) and so read as smaller than their
// neighbours at the same pixelSize. Crucially it affects only what is
// *rendered*: implicitHeight below stays the row's nominal line box, so an
// oversized glyph overflows its cell instead of inflating the bar's RowLayout
// and shoving every vertically-centred sibling off the row's centre line. That
// used to need a `Layout.preferredHeight: contentHeight` override at each such
// widget's call site in shell.qml.
//
// `padding` widens the click target for narrow glyphs (the power symbol, the
// bell) without changing where the glyph itself sits.
Item {
    id: barIcon

    // The glyph itself. Callers with a codepoint should pass
    // String.fromCodePoint(0x...); callers with a literal can pass it directly.
    property string glyph: ""
    property color color: Theme.colFg
    property int oversize: 0
    property int padding: 0

    FontMetrics {
        id: metrics
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
    }

    implicitWidth: label.implicitWidth + barIcon.padding
    implicitHeight: Math.ceil(metrics.height)

    Text {
        id: label
        anchors.centerIn: parent
        text: barIcon.glyph
        color: barIcon.color
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize + barIcon.oversize }
    }
}
