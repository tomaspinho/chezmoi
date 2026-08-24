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
    implicitHeight: 30
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
    property int fontSize: 14

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
        anchors.fill: parent
        anchors.margins: 8

        Repeater {
            model: 4

            Text {
                property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
                property bool isActive: Hyprland.focusedWorkspace?.id === index + 1
                text: index + 1
                color: isActive ? "#0db9d7" : (ws ? "#7aa2f7" : "#444b6a")
                font { pixelSize: 14; bold: true }

                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch(`hl.dsp.focus({ workspace = ${index + 1} })`)
                }
            }
        }

        Item { Layout.fillWidth: true }

        SystemTrayIndicator {
            Layout.rightMargin: 10
            Layout.alignment: Qt.AlignVCenter
            colFg: root.colFg
            fontSize: root.fontSize
        }

        WifiIndicator {
            Layout.rightMargin: 10
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

        BluetoothIndicator {
            Layout.rightMargin: 10
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

        VolumeIndicator {
            Layout.rightMargin: 10
            Layout.alignment: Qt.AlignVCenter
            colBg: root.colBg
            colFg: root.colFg
            colMuted: root.colMuted
            colCyan: root.colCyan
            fontFamily: root.fontFamily
            fontSize: root.fontSize
        }

        BrightnessIndicator {
            Layout.rightMargin: 10
            Layout.alignment: Qt.AlignVCenter
            colBg: root.colBg
            colFg: root.colFg
            colMuted: root.colMuted
            colYellow: root.colYellow
            fontFamily: root.fontFamily
            fontSize: root.fontSize
        }

        // nightlight manager
        ProcessToggle {
            Layout.rightMargin: 10
            Layout.alignment: Qt.AlignVCenter
            processName: "hyprsunset"
            glyphOn: 0xF1A4C
            glyphOff: 0xF1A4D
            colOn: root.colYellow
            colOff: root.colMuted
            fontFamily: root.fontFamily
            fontSize: root.fontSize
        }

        // idle manager
        ProcessToggle {
            Layout.rightMargin: 10
            Layout.alignment: Qt.AlignVCenter
            processName: "hypridle"
            glyphOn: 0xF04B2
            glyphOff: 0xF04B3
            colOn: root.colCyan
            colOff: root.colMuted
            fontFamily: root.fontFamily
            fontSize: root.fontSize
        }

        BatteryIndicator {
            Layout.rightMargin: 10
            Layout.alignment: Qt.AlignVCenter
            colFg: root.colFg
            colMuted: root.colMuted
            colGreen: root.colGreen
            colYellow: root.colYellow
            colRed: root.colRed
            fontFamily: root.fontFamily
            fontSize: root.fontSize
        }

        Text {
            id: clock
            color: root.colBlue
            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
            text: Qt.formatDateTime(new Date(), "ddd, MMM dd - HH:mm")

            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd, MMM dd - HH:mm")
            }
        }

        PowerMenu {
            Layout.leftMargin: 12
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
