// Starts quickshell on QApplication instead of QGuiApplication, which is what
// makes the *real* Qt widget menus available. Tray app-indicator menus are
// DBusMenu trees owned by the client app; QsMenuAnchor/SystemTrayItem.display()
// hand them to the platform to render as a native QMenu, but quickshell refuses
// ("Cannot call QsMenuAnchor.open() as quickshell was not started in
// QApplication mode") unless this pragma is on the *root* QML file. Without it
// the only option is re-drawing the menu tree by hand in QML, which loses
// submenus, keyboard nav and grab handling. Must stay above the imports.
//@ pragma UseQApplication

import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: root.contentHeight + root.barPadding * 2
    color: "#1a1b26"
    property color colBg: "#1a1b26"
    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colCyan: "#0db9d7"
    property color colBlue: "#7aa2f7"
    property color colYellow: "#e0af68"
    property color colGreen: "#9ece6a"
    property color colRed: "#f7768e"
    property string fontFamily: "JetBrainsMono Nerd Font"

    // One size for everything on the bar. Every widget takes this via its own
    // fontSize property; nothing on the bar derives a size from it any more.
    property int fontSize: 14

    // Every Text on the bar is one line, so its height is exactly this font's
    // line box. Driving the panel off the metrics rather than a measured ink
    // box means each item fills the row exactly and is therefore centred by
    // construction — and it keeps following fontSize if that ever changes.
    FontMetrics {
        id: barFont
        font.family: root.fontFamily
        font.pixelSize: root.fontSize
    }

    property int contentHeight: Math.ceil(barFont.height)

    // Breathing room above and below the content row. The panel is the content
    // plus exactly this twice, so the gap top and bottom is symmetric by
    // construction. Kept at 1 because the line box already carries the optical
    // padding: ascent reaches above the cap height and descent below the
    // baseline, which leaves ~4px clear either side of the glyphs.
    property int barPadding: 1

    // Single knob for the gap between status items. Nerd Font glyphs carry a
    // couple of px of side bearing inside their own advance width, so the gap
    // that actually reads on screen is a few px wider than this.
    //
    // Each separator is itself a layout child, so it takes this gap on *both*
    // sides — halved from 8 to keep the widget-to-widget distance where it was
    // before the rules were added.
    property int itemGap: 4

    // centered on the panel itself, not on the gap between the side items
    Text {
        id: windowTitle
        anchors.centerIn: parent
        width: Math.min(implicitWidth, root.width * 0.3)
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideRight
        color: root.colFg
        font { family: root.fontFamily; pixelSize: root.fontSize }
        text: Hyprland.activeToplevel?.title ?? ""
    }

    RowLayout {
        // Horizontal margins only, and an explicit content height rather than
        // filling the panel: the vertical breathing room is barPadding, so the
        // row must not claim it.
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        height: root.contentHeight
        spacing: root.itemGap

        // Workspaces keep their own spacing so they stay tight as a group and
        // don't inherit the (wider) gap used between status items.
        Row {
            Layout.alignment: Qt.AlignVCenter
            spacing: 5

            Repeater {
                model: 4

                Text {
                    property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
                    property bool isActive: Hyprland.focusedWorkspace?.id === index + 1
                    text: index + 1
                    color: isActive ? "#0db9d7" : (ws ? "#7aa2f7" : "#444b6a")
                    font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }

                    MouseArea {
                        anchors.fill: parent
                        onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${index + 1} })`)
                    }
                }
            }
        }

        Item { Layout.fillWidth: true }

        SystemTrayIndicator {
            Layout.alignment: Qt.AlignVCenter
            colFg: root.colFg
            fontSize: root.fontSize
        }

        BarSeparator { Layout.alignment: Qt.AlignVCenter; color: root.colMuted }

        WifiIndicator {
            Layout.alignment: Qt.AlignVCenter
            colBg: root.colBg
            colFg: root.colFg
            colMuted: root.colMuted
            colCyan: root.colCyan
            colBlue: root.colBlue
            colYellow: root.colYellow
            fontFamily: root.fontFamily
            fontSize: root.fontSize
        }

        BarSeparator { Layout.alignment: Qt.AlignVCenter; color: root.colMuted }

        BluetoothIndicator {
            Layout.alignment: Qt.AlignVCenter
            colBg: root.colBg
            colFg: root.colFg
            colMuted: root.colMuted
            colCyan: root.colCyan
            colBlue: root.colBlue
            colYellow: root.colYellow
            fontFamily: root.fontFamily
            fontSize: root.fontSize
        }

        BarSeparator { Layout.alignment: Qt.AlignVCenter; color: root.colMuted }

        VolumeIndicator {
            Layout.alignment: Qt.AlignVCenter
            colBg: root.colBg
            colFg: root.colFg
            colMuted: root.colMuted
            colCyan: root.colCyan
            fontFamily: root.fontFamily
            fontSize: root.fontSize
        }

        BarSeparator { Layout.alignment: Qt.AlignVCenter; color: root.colMuted }

        BrightnessIndicator {
            Layout.alignment: Qt.AlignVCenter
            colBg: root.colBg
            colFg: root.colFg
            colMuted: root.colMuted
            colYellow: root.colYellow
            fontFamily: root.fontFamily
            fontSize: root.fontSize
        }

        BarSeparator { Layout.alignment: Qt.AlignVCenter; color: root.colMuted }

        // nightlight manager
        ProcessToggle {
            Layout.alignment: Qt.AlignVCenter
            processName: "hyprsunset"
            glyphOn: 0xF1A4C
            glyphOff: 0xF1A4D
            colOn: root.colYellow
            colOff: root.colMuted
            fontFamily: root.fontFamily
            fontSize: root.fontSize
        }

        BarSeparator { Layout.alignment: Qt.AlignVCenter; color: root.colMuted }

        // idle manager
        ProcessToggle {
            Layout.alignment: Qt.AlignVCenter
            processName: "hypridle"
            glyphOn: 0xF04B2
            glyphOff: 0xF04B3
            colOn: root.colCyan
            colOff: root.colMuted
            fontFamily: root.fontFamily
            fontSize: root.fontSize
        }

        BarSeparator { Layout.alignment: Qt.AlignVCenter; color: root.colMuted }

        BatteryIndicator {
            Layout.alignment: Qt.AlignVCenter
            colFg: root.colFg
            colMuted: root.colMuted
            colGreen: root.colGreen
            colYellow: root.colYellow
            colRed: root.colRed
            fontFamily: root.fontFamily
            fontSize: root.fontSize
        }

        BarSeparator { Layout.alignment: Qt.AlignVCenter; color: root.colMuted }

        Text {
            id: clock

            // MM is the month; lowercase mm is minutes, so "dd-mm-yyyy" would
            // render the minute where the month belongs. Kept in one place so
            // the initial value and the tick below can't drift apart.
            readonly property string format: "HH:mm dd-MM-yyyy"

            color: root.colBlue
            font { family: root.fontFamily; pixelSize: root.fontSize }
            text: Qt.formatDateTime(new Date(), format)

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clock.text = Qt.formatDateTime(new Date(), clock.format)
            }
        }

        BarSeparator { Layout.alignment: Qt.AlignVCenter; color: root.colMuted }

        PowerMenu {
            Layout.alignment: Qt.AlignVCenter
            colBg: root.colBg
            colFg: root.colFg
            colMuted: root.colMuted
            colRed: root.colRed
            fontFamily: root.fontFamily
            fontSize: root.fontSize
        }
    }
}
