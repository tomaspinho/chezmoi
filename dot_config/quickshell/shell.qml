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
import Quickshell.Io
import QtQuick
import QtQuick.Layouts

PanelWindow {
    id: root
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: root.contentHeight + root.barPadding * 2 + root.borderWidth
    color: "#1a1b26"

    // OnDemand rather than None: the bar never remaps (it's mapped once at
    // launch and stays that way all session), so unlike
    // NotificationHistoryPane.qml this is safe to have statically - it's
    // specifically what makes the Escape handler below reachable at all,
    // since clicking any bar icon (e.g. NotificationHistoryButton) grants
    // the bar keyboard focus under OnDemand semantics. That handler exists
    // here rather than on the pane itself because giving *that* ephemeral,
    // repeatedly-mapped surface its own keyboard focus (even just
    // WlrKeyboardFocus.OnDemand, even without ever forcing it) was
    // observed to corrupt click hit-testing on the bar's own buttons.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // `focus`/`Keys` aren't available directly on PanelWindow itself (it's
    // not a plain Item) - this is the focus scope that actually receives
    // Escape once WlrKeyboardFocus above grants the bar's surface
    // keyboard focus.
    Item {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: if (notificationHistory.open) notificationHistory.hide()
    }

    property color colBg: "#1a1b26"
    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colCyan: "#0db9d7"
    property color colBlue: "#7aa2f7"
    property color colYellow: "#e0af68"
    property color colGreen: "#9ece6a"
    property color colRed: "#f7768e"
    property string fontFamily: "JetBrainsMono Nerd Font"

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
            onStreamFinished: root.hostname = text.trim()
        }
    }

    // Its own top-level layer-shell surface (see Notifications.qml), not a
    // bar widget - popups float independently of the bar's position/size.
    Notifications {
        id: notifications
        topOffset: root.height
        colBg: root.colBg
        colFg: root.colFg
        colMuted: root.colMuted
        colBlue: root.colBlue
        colYellow: root.colYellow
        colRed: root.colRed
        fontFamily: root.fontFamily
        fontSize: root.fontSize
    }

    // Also its own top-level surface (see AppLauncher.qml). Has no bar
    // widget at all - opened via `qs ipc call launcher toggle`, meant to be
    // bound to a compositor keybind.
    AppLauncher {
        colBg: root.colBg
        colFg: root.colFg
        colMuted: root.colMuted
        colBlue: root.colBlue
        fontFamily: root.fontFamily
        fontSize: root.fontSize
    }

    // Also its own top-level surface (see NotificationHistoryPane.qml) -
    // needs the full screen height to slide in from the right, which the
    // bar's NotificationHistoryButton (its toggle target) can't provide on
    // its own.
    NotificationHistoryPane {
        id: notificationHistory
        history: notifications.history
        onClearRequested: notifications.clearHistory()
        onDismissRequested: id => notifications.removeHistoryEntry(id)
        colBg: root.colBg
        colFg: root.colFg
        colMuted: root.colMuted
        colBlue: root.colBlue
        colRed: root.colRed
        fontFamily: root.fontFamily
        fontSize: root.fontSize
    }

    // One size for everything on the bar. Every widget takes this via its own
    // fontSize property; nothing on the bar derives a size from it any more.
    property int fontSize: hostname === officeHostname ? 16 : 14

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

    // Hairline rule separating the bar from the windows below it. The panel is
    // this much taller than the content row plus its padding, so the border is
    // its own row of pixels rather than eating into the bottom gap.
    property int borderWidth: 1

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: root.borderWidth
        color: root.colMuted
    }

    // centered on the panel itself, not on the gap between the side items.
    // Vertically it follows the content row rather than the panel, so the
    // border's row of pixels doesn't pull it off the row's centre line.
    WindowTitle {
        id: windowTitle
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: statusRow.verticalCenter
        maxWidth: root.width * 0.3
        color: root.colFg
        font { family: root.fontFamily; pixelSize: root.fontSize }
    }

    RowLayout {
        id: statusRow

        // Horizontal margins only, and an explicit content height rather than
        // filling the panel: the vertical breathing room is barPadding, so the
        // row must not claim it.
        //
        // Anchored to the top with barPadding rather than vertically centred:
        // centring in a panel that now carries an odd extra pixel for the
        // border would land the row on a half-pixel and blur the text.
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.top: parent.top
        anchors.topMargin: root.barPadding
        height: root.contentHeight
        spacing: root.itemGap

        WorkspaceSelector {
            Layout.alignment: Qt.AlignVCenter
            colMuted: root.colMuted
            colCyan: root.colCyan
            colBlue: root.colBlue
            fontFamily: root.fontFamily
            fontSize: root.fontSize
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
            // The icon glyph is drawn at fontSize+4 (see WifiIndicator.qml) to
            // compensate for how small it reads at the true size, which makes
            // this item's own implicitHeight taller than everyone else's. Left
            // alone, that inflates the *row's* implicitHeight past contentHeight,
            // and RowLayout centers every Qt.AlignVCenter sibling against that
            // inflated figure rather than the row's real (clamped) height -
            // pushing plain text like the clock and workspace numbers visibly
            // below true centre. Pinning preferredHeight keeps this cell's
            // footprint the same as everyone else's; the oversized glyph still
            // renders centered within it, just overflowing the cell slightly.
            Layout.preferredHeight: root.contentHeight
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
            id: brightness
            Layout.alignment: Qt.AlignVCenter
            colBg: root.colBg
            colFg: root.colFg
            colMuted: root.colMuted
            colYellow: root.colYellow
            fontFamily: root.fontFamily
            fontSize: root.fontSize
        }

        // Tied to the widget's own visibility: on machines with no
        // controllable backlight (visible: false, above), this would
        // otherwise still draw and leave a doubled-up separator.
        BarSeparator {
            Layout.alignment: Qt.AlignVCenter
            color: root.colMuted
            visible: brightness.available
        }

        // nightlight manager
        ProcessToggle {
            Layout.alignment: Qt.AlignVCenter
            // See the comment on WifiIndicator's Layout.preferredHeight above:
            // this glyph is also drawn oversized (fontSize+4) to compensate for
            // reading small, which would otherwise inflate the row's own
            // implicitHeight and push every plain-text sibling below centre.
            Layout.preferredHeight: root.contentHeight
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
            Layout.preferredHeight: root.contentHeight
            processName: "hypridle"
            glyphOn: 0xF04B2
            glyphOff: 0xF04B3
            colOn: root.colCyan
            colOff: root.colMuted
            fontFamily: root.fontFamily
            fontSize: root.fontSize
        }

        // Tied to the battery's own visibility: on machines with no battery
        // (visible: false, above), this would otherwise still draw and leave
        // a doubled-up separator next to the one before the clock.
        BarSeparator {
            Layout.alignment: Qt.AlignVCenter
            color: root.colMuted
            visible: battery.available
        }

        BatteryIndicator {
            id: battery
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

        // Hovering it opens a day-of-week + month-calendar popover; see
        // Clock.qml.
        Clock {
            Layout.alignment: Qt.AlignVCenter
            colBg: root.colBg
            colFg: root.colFg
            colMuted: root.colMuted
            colBlue: root.colBlue
            colYellow: root.colYellow
            colGreen: root.colGreen
            fontFamily: root.fontFamily
            fontSize: root.fontSize
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

        BarSeparator { Layout.alignment: Qt.AlignVCenter; color: root.colMuted }

        NotificationHistoryButton {
            Layout.alignment: Qt.AlignVCenter
            open: notificationHistory.open
            historyCount: notifications.history.length
            onToggleRequested: notificationHistory.toggle()
            colFg: root.colFg
            colMuted: root.colMuted
            colBlue: root.colBlue
            fontFamily: root.fontFamily
            fontSize: root.fontSize
        }
    }
}
