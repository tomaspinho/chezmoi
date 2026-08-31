import Quickshell
import Quickshell.Hyprland
import QtQuick

Item {
    id: clock

    property color colBg: "#1a1b26"
    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colBlue: "#7aa2f7"
    property color colYellow: "#e0af68"
    property color colGreen: "#9ece6a"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14

    // MM is the month; lowercase mm is minutes, so "dd-mm-yyyy" would render
    // the minute where the month belongs.
    readonly property string format: "HH:mm dd-MM-yyyy"

    // Single source of truth for both the bar label and the calendar's notion
    // of "today", so the highlighted cell rolls over at midnight on its own
    // rather than only when the shell is reloaded.
    property date now: new Date()

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: clock.now = new Date()
    }

    // Months away from the current one, driven by the popover's arrows. Reset
    // whenever the popover closes so it always reopens on the current month.
    property int viewOffset: 0

    readonly property date viewDate: new Date(now.getFullYear(), now.getMonth() + viewOffset, 1)

    // Monday-first 6x7 grid. Always 42 cells (the largest a month can span:
    // 31 days starting on a Sunday), so the popover never changes height as
    // the user pages through months. Leading/trailing cells spill into the
    // neighbouring months and are drawn muted.
    readonly property var cells: {
        const first = new Date(viewDate.getFullYear(), viewDate.getMonth(), 1);
        // getDay() is Sunday-based; shift so Monday is 0.
        const offset = (first.getDay() + 6) % 7;
        const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(first.getFullYear(), first.getMonth(), 1 - offset + i);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === first.getMonth(),
                weekend: d.getDay() === 0 || d.getDay() === 6,
                today: d.getTime() === today.getTime()
            });
        }
        return out;
    }

    readonly property var weekdays: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

    // Popover visibility, click-triggered - same expand/focus-grab
    // arrangement as VolumeIndicator's fader.
    property bool popoverVisible: false

    onPopoverVisibleChanged: if (!popoverVisible) viewOffset = 0

    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight

    Text {
        id: label
        anchors.centerIn: parent
        text: Qt.formatDateTime(clock.now, clock.format)
        color: clock.colBlue
        font { family: clock.fontFamily; pixelSize: clock.fontSize }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: clock.popoverVisible = !clock.popoverVisible
    }

    HyprlandFocusGrab {
        active: clock.popoverVisible
        windows: [popover]
        onCleared: clock.popoverVisible = false
    }

    PopupWindow {
        id: popover

        anchor {
            item: clock
            edges: Edges.Bottom
            gravity: Edges.Bottom | Edges.Left
            margins.top: 6
        }

        color: "transparent"
        visible: clock.popoverVisible
        // Seven columns plus the frame's margins, rather than a hand-tuned
        // number like the other popups use - it keeps the width following
        // fontSize. Computed from cellSize rather than read back off the grid
        // because the column's children size themselves off the frame's width,
        // so deriving the frame's width from them would be a binding loop.
        implicitWidth: cellSize * 7 + 24
        implicitHeight: frame.implicitHeight

        readonly property int cellSize: Math.round(clock.fontSize * 2.2)

        Rectangle {
            id: frame
            anchors.fill: parent
            implicitHeight: column.implicitHeight + 24
            color: clock.colBg
            radius: 8
            border { width: 1; color: clock.colMuted }

            Column {
                id: column
                anchors { fill: parent; margins: 12 }
                spacing: 8

                // Day of the week, spelled out, with the full date under it -
                // the bar label is numeric-only, so this is the part that
                // answers "what day is it?" at a glance.
                Column {
                    width: parent.width
                    spacing: 1

                    Text {
                        text: Qt.formatDate(clock.now, "dddd")
                        color: clock.colBlue
                        font { family: clock.fontFamily; pixelSize: clock.fontSize + 4; bold: true }
                    }

                    Text {
                        text: Qt.formatDate(clock.now, "d MMMM yyyy")
                        color: clock.colMuted
                        font { family: clock.fontFamily; pixelSize: clock.fontSize - 3 }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: clock.colMuted
                }

                // Month header. The title doubles as "back to today" so paging
                // away is always one click from being undone; the arrows page
                // by a month either way.
                Item {
                    width: parent.width
                    height: Math.round(clock.fontSize * 1.6)

                    Text {
                        id: prev
                        anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                        text: String.fromCodePoint(0xF0141) // md-chevron-left
                        color: prevHover.hovered ? clock.colBlue : clock.colMuted
                        font { family: clock.fontFamily; pixelSize: clock.fontSize + 2 }

                        HoverHandler { id: prevHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: clock.viewOffset-- }
                    }

                    Text {
                        // Which direction we've paged, at a glance: blue is
                        // the month we're actually in, yellow is behind it,
                        // green ahead of it. Hover lightens whichever of the
                        // three applies rather than switching to a fixed
                        // colour, so the affordance doesn't overwrite the
                        // meaning.
                        readonly property color base: clock.viewOffset === 0 ? clock.colBlue
                            : clock.viewOffset < 0 ? clock.colYellow : clock.colGreen

                        anchors.centerIn: parent
                        text: Qt.formatDate(clock.viewDate, "MMMM yyyy")
                        color: titleHover.hovered ? Qt.lighter(base, 1.3) : base
                        font { family: clock.fontFamily; pixelSize: clock.fontSize - 1 }

                        HoverHandler {
                            id: titleHover
                            // Only offers anything to click when we're actually
                            // away from the current month.
                            enabled: clock.viewOffset !== 0
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            enabled: clock.viewOffset !== 0
                            onTapped: clock.viewOffset = 0
                        }
                    }

                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: String.fromCodePoint(0xF0142) // md-chevron-right
                        color: nextHover.hovered ? clock.colBlue : clock.colMuted
                        font { family: clock.fontFamily; pixelSize: clock.fontSize + 2 }

                        HoverHandler { id: nextHover; cursorShape: Qt.PointingHandCursor }
                        TapHandler { onTapped: clock.viewOffset++ }
                    }
                }

                Grid {
                    id: grid
                    columns: 7
                    rows: 7
                    anchors.horizontalCenter: parent.horizontalCenter

                    // Weekday initials, then the 42 date cells - one flat
                    // Grid rather than a header Row plus a body Grid, so the
                    // columns line up by construction instead of by matching
                    // two independent cell widths.
                    Repeater {
                        model: clock.weekdays

                        Item {
                            required property string modelData
                            width: popover.cellSize
                            height: popover.cellSize

                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData
                                color: clock.colMuted
                                font { family: clock.fontFamily; pixelSize: clock.fontSize - 4; bold: true }
                            }
                        }
                    }

                    Repeater {
                        model: clock.cells

                        Rectangle {
                            required property var modelData

                            width: popover.cellSize
                            height: popover.cellSize
                            radius: 4
                            color: modelData.today ? clock.colBlue : "transparent"

                            Text {
                                anchors.centerIn: parent
                                text: parent.modelData.day
                                color: parent.modelData.today ? clock.colBg
                                    : !parent.modelData.inMonth ? Qt.darker(clock.colMuted, 1.4)
                                    : parent.modelData.weekend ? clock.colYellow
                                    : clock.colFg
                                font {
                                    family: clock.fontFamily
                                    pixelSize: clock.fontSize - 2
                                    bold: parent.modelData.today
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
