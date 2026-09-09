import Quickshell
import Quickshell.Hyprland
import QtQuick

Item {
    id: clock


    // MM is the month; lowercase mm is minutes, so "dd-mm-yyyy" would render
    // the minute where the month belongs.
    readonly property string format: "HH:mm dd-MM-yyyy"

    // Single source of truth for both the bar label and the calendar's notion
    // of "today", so the highlighted cell rolls over at midnight on its own
    // rather than only when the shell is reloaded.
    //
    // Minutes precision, not Seconds: the label's finest field is mm, so a
    // per-second tick would just be re-rendering the same string 59 times over
    // (and, before the day/month keys below, rebuilding the whole calendar
    // with it). SystemClock also aligns its wakeups to the wall clock, so the
    // minute rolls over on time rather than up to a second late.
    SystemClock {
        id: systemClock
        precision: SystemClock.Minutes
    }

    readonly property date now: systemClock.date

    // Months away from the current one, driven by the popover's arrows. Reset
    // whenever the popover closes so it always reopens on the current month.
    property int viewOffset: 0

    // `now` changes identity every minute, so anything deriving from it
    // directly rebuilds every minute too. These two keys re-evaluate on that
    // same tick but their *values* only change when the day (or the viewed
    // month) actually does - and QML only notifies on a real change - which is
    // what keeps the 42-cell grid below from being rebuilt 1440 times a day to
    // produce the same answer.
    //
    // yyyymmdd, deliberately not a getTime() timestamp: QML's `int` is 32-bit,
    // and epoch milliseconds (~1.79e12 as of writing) silently truncate to
    // their low 32 bits. That is not a rounding error - it landed the whole
    // calendar in January 1970.
    function dayKey(date) {
        return date.getFullYear() * 10000 + (date.getMonth() + 1) * 100 + date.getDate();
    }

    readonly property int todayKey: clock.dayKey(now)

    // Months since year 0, so paging past a year boundary is just ±1.
    readonly property int viewMonthIndex:
        now.getFullYear() * 12 + now.getMonth() + viewOffset

    readonly property date viewDate:
        new Date(Math.floor(viewMonthIndex / 12), viewMonthIndex % 12, 1)

    // Monday-first 6x7 grid. Always 42 cells (the largest a month can span:
    // 31 days starting on a Sunday), so the popover never changes height as
    // the user pages through months. Leading/trailing cells spill into the
    // neighbouring months and are drawn muted.
    //
    // Reads viewDate and todayKey only - deliberately not `now`, whose
    // identity changes every minute and would drag the whole rebuild back
    // onto that tick.
    readonly property var cells: {
        const first = new Date(viewDate.getFullYear(), viewDate.getMonth(), 1);
        // getDay() is Sunday-based; shift so Monday is 0.
        const offset = (first.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++) {
            const d = new Date(first.getFullYear(), first.getMonth(), 1 - offset + i);
            out.push({
                day: d.getDate(),
                inMonth: d.getMonth() === first.getMonth(),
                weekend: d.getDay() === 0 || d.getDay() === 6,
                today: clock.dayKey(d) === clock.todayKey
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
        color: Theme.colBlue
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
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

    BarPopup {
        id: popover
        anchorItem: clock
        visible: clock.popoverVisible
        // Seven columns plus the frame's margins, rather than a hand-tuned
        // number like the other popups use - it keeps the width following
        // fontSize. Computed from cellSize rather than read back off the grid
        // because the column's children size themselves off the frame's width,
        // so deriving the frame's width from them would be a binding loop.
        popupWidth: cellSize * 7 + 24
        contentMargin: 12
        contentPadding: 24
        spacing: 8

        readonly property int cellSize: Math.round(Theme.fontSize * 2.2)

        // Day of the week, spelled out, with the full date under it -
        // the bar label is numeric-only, so this is the part that
        // answers "what day is it?" at a glance.
        Column {
            width: parent.width
            spacing: 1

            Text {
                text: Qt.formatDate(clock.now, "dddd")
                color: Theme.colBlue
                font { family: Theme.fontFamily; pixelSize: Theme.fontSize + 4; bold: true }
            }

            Text {
                text: Qt.formatDate(clock.now, "d MMMM yyyy")
                color: Theme.colMuted
                font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 3 }
            }
        }

        PopupDivider {}

        // Month header. The title doubles as "back to today" so paging
        // away is always one click from being undone; the arrows page
        // by a month either way.
        Item {
            width: parent.width
            height: Math.round(Theme.fontSize * 1.6)

            Text {
                id: prev
                anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                text: String.fromCodePoint(0xF0141) // md-chevron-left
                color: prevHover.hovered ? Theme.colBlue : Theme.colMuted
                font { family: Theme.fontFamily; pixelSize: Theme.fontSize + 2 }

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
                readonly property color base: clock.viewOffset === 0 ? Theme.colBlue
                    : clock.viewOffset < 0 ? Theme.colYellow : Theme.colGreen

                anchors.centerIn: parent
                text: Qt.formatDate(clock.viewDate, "MMMM yyyy")
                color: titleHover.hovered ? Qt.lighter(base, 1.3) : base
                font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 1 }

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
                color: nextHover.hovered ? Theme.colBlue : Theme.colMuted
                font { family: Theme.fontFamily; pixelSize: Theme.fontSize + 2 }

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
                        color: Theme.colMuted
                        font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 4; bold: true }
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
                    color: modelData.today ? Theme.colBlue : "transparent"

                    Text {
                        anchors.centerIn: parent
                        text: parent.modelData.day
                        color: parent.modelData.today ? Theme.colBg
                            : !parent.modelData.inMonth ? Qt.darker(Theme.colMuted, 1.4)
                            : parent.modelData.weekend ? Theme.colYellow
                            : Theme.colFg
                        font {
                            family: Theme.fontFamily
                            pixelSize: Theme.fontSize - 2
                            bold: parent.modelData.today
                        }
                    }
                }
            }
        }
    }
}
