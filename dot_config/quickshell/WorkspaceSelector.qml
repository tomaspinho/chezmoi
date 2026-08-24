import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts

// The workspace strip: a fixed 1..count run of clickable numbers.
//
// Deliberately fixed rather than driven off Hyprland.workspaces, so the strip
// never reflows as workspaces come and go and an empty workspace still has
// somewhere to click. Existence only changes a number's colour.
Row {
    id: workspaces

    property color colMuted: "#444b6a"
    property color colCyan: "#0db9d7"
    property color colBlue: "#7aa2f7"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14

    property int count: 4

    // Workspaces keep their own spacing so they read as one group and don't
    // inherit the (wider) gap the bar uses between status items.
    spacing: 5

    Repeater {
        model: workspaces.count

        RowLayout {
            id: entry
            required property int index

            // Hyprland numbers workspaces from 1; the Repeater index from 0.
            readonly property int wsId: entry.index + 1

            Text {
                // Non-null once the workspace actually exists, i.e. once
                // something has been opened on it.
                readonly property var ws:
                    Hyprland.workspaces.values.find(w => w.id === entry.wsId)
                readonly property bool isActive:
                    Hyprland.focusedWorkspace?.id === entry.wsId

                text: entry.wsId
                color: isActive ? workspaces.colCyan
                    : ws ? workspaces.colBlue
                    : workspaces.colMuted
                font { family: workspaces.fontFamily; pixelSize: workspaces.fontSize }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(
                        `hl.dsp.focus({ workspace = ${entry.wsId} })`)
                }
            }

            // Rules go *between* numbers, so the last one has none.
            BarSeparator {
                color: workspaces.colMuted
                visible: entry.wsId < workspaces.count
            }
        }
    }
}
