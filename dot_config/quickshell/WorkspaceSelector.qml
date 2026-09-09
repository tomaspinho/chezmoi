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
                color: isActive ? Theme.colCyan
                    : ws ? Theme.colBlue
                    : Theme.colMuted
                font { family: Theme.fontFamily; pixelSize: Theme.fontSize }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Hyprland.dispatch(
                        `hl.dsp.focus({ workspace = ${entry.wsId} })`)
                }
            }

            // Rules go *between* numbers, so the last one has none.
            BarSeparator {
                visible: entry.wsId < workspaces.count
            }
        }
    }
}
