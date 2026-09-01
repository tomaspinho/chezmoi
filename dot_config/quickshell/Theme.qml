pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick

// Every colour, font and bar metric in one place. Widgets read these directly
// (`Theme.colFg`) rather than declaring their own copy of the palette and
// having shell.qml hand it down - which previously meant the eight colour
// literals appeared in sixteen files and adding one meant editing seventeen.
//
// Quickshell generates a qmldir for the config directory, so `pragma Singleton`
// is all that's needed to make this reachable by type name from anywhere.
Singleton {
    id: theme

    readonly property color colBg: "#1a1b26"
    readonly property color colFg: "#a9b1d6"
    readonly property color colMuted: "#444b6a"
    readonly property color colCyan: "#0db9d7"
    readonly property color colBlue: "#7aa2f7"
    readonly property color colYellow: "#e0af68"
    readonly property color colGreen: "#9ece6a"
    readonly property color colRed: "#f7768e"

    readonly property string fontFamily: "JetBrainsMono Nerd Font"

    // Per-machine: this config is shared across machines (desktop + laptop),
    // and this desktop ("office") gets a bigger base size than everywhere
    // else, which stays at the 14 default. Starts at the default and flips
    // once hostnameProc reports back, same startup-lag tradeoff as the other
    // widgets that read their state from an external process.
    readonly property string officeHostname: "office"
    property string hostname: ""

    Process {
        id: hostnameProc
        command: ["hostname"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: theme.hostname = text.trim()
        }
    }

    // One size for everything on the bar. Nothing derives a size from this any
    // more; widgets that need a bigger glyph add a fixed offset to it locally.
    readonly property int fontSize: hostname === officeHostname ? 16 : 14

    // Every Text on the bar is one line, so its height is exactly this font's
    // line box. Driving the panel off the metrics rather than a measured ink
    // box means each item fills the row exactly and is therefore centred by
    // construction — and it keeps following fontSize if that ever changes.
    FontMetrics {
        id: barFont
        font.family: theme.fontFamily
        font.pixelSize: theme.fontSize
    }

    readonly property int contentHeight: Math.ceil(barFont.height)

    // Breathing room above and below the content row. The panel is the content
    // plus exactly this twice, so the gap top and bottom is symmetric by
    // construction. Kept at 1 because the line box already carries the optical
    // padding: ascent reaches above the cap height and descent below the
    // baseline, which leaves ~4px clear either side of the glyphs.
    readonly property int barPadding: 1

    // Single knob for the gap between status items. Nerd Font glyphs carry a
    // couple of px of side bearing inside their own advance width, so the gap
    // that actually reads on screen is a few px wider than this.
    //
    // Each separator is itself a layout child, so it takes this gap on *both*
    // sides — halved from 8 to keep the widget-to-widget distance where it was
    // before the rules were added.
    readonly property int itemGap: 4

    // Hairline rule separating the bar from the windows below it. The panel is
    // this much taller than the content row plus its padding, so the border is
    // its own row of pixels rather than eating into the bottom gap.
    readonly property int borderWidth: 1
}
