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
import QtQuick
import QtQuick.Layouts

// The bar itself. Every colour, font and metric comes from Theme.qml, which
// each widget reads directly - so this file is only about *what* is on the bar
// and in what order, never about how any of it is styled.
PanelWindow {
    id: root
    anchors.top: true
    anchors.left: true
    anchors.right: true
    implicitHeight: Theme.contentHeight + Theme.barPadding * 2 + Theme.borderWidth
    color: Theme.colBg

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

    // Its own top-level layer-shell surface (see Notifications.qml), not a
    // bar widget - popups float independently of the bar's position/size.
    Notifications {
        id: notifications
        topOffset: root.height
    }

    // Also its own top-level surface (see AppLauncher.qml). Has no bar
    // widget at all - opened via `qs ipc call launcher toggle`, meant to be
    // bound to a compositor keybind.
    AppLauncher {}

    // Also its own top-level surface (see NotificationHistoryPane.qml) -
    // needs the full screen height to slide in from the right, which the
    // bar's NotificationHistoryButton (its toggle target) can't provide on
    // its own.
    NotificationHistoryPane {
        id: notificationHistory
        history: notifications.history
        onClearRequested: notifications.clearHistory()
        onDismissRequested: id => notifications.removeHistoryEntry(id)
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        height: Theme.borderWidth
        color: Theme.colMuted
    }

    // centered on the panel itself, not on the gap between the side items.
    // Vertically it follows the content row rather than the panel, so the
    // border's row of pixels doesn't pull it off the row's centre line.
    WindowTitle {
        id: windowTitle
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: statusRow.verticalCenter
        maxWidth: root.width * 0.3
        color: Theme.colFg
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
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
        anchors.topMargin: Theme.barPadding
        height: Theme.contentHeight
        spacing: Theme.itemGap

        WorkspaceSelector {
            Layout.alignment: Qt.AlignVCenter
        }

        Item { Layout.fillWidth: true }

        SystemTrayIndicator {
            Layout.alignment: Qt.AlignVCenter
        }

        BarSeparator { Layout.alignment: Qt.AlignVCenter }

        // Widgets whose glyph is drawn oversized (WifiIndicator, ProcessToggle)
        // report the row's nominal height as their own implicitHeight rather
        // than the glyph's, so they no longer inflate this RowLayout's implicit
        // height and shove every AlignVCenter sibling off centre. See BarIcon.
        WifiIndicator {
            Layout.alignment: Qt.AlignVCenter
        }

        BarSeparator { Layout.alignment: Qt.AlignVCenter }

        BluetoothIndicator {
            Layout.alignment: Qt.AlignVCenter
        }

        BarSeparator { Layout.alignment: Qt.AlignVCenter }

        VolumeIndicator {
            Layout.alignment: Qt.AlignVCenter
        }

        BarSeparator { Layout.alignment: Qt.AlignVCenter }

        BrightnessIndicator {
            id: brightness
            Layout.alignment: Qt.AlignVCenter
        }

        // Tied to the widget's own visibility: on machines with no
        // controllable backlight (visible: false, above), this would
        // otherwise still draw and leave a doubled-up separator.
        BarSeparator {
            Layout.alignment: Qt.AlignVCenter
            visible: brightness.available
        }

        // nightlight manager
        ProcessToggle {
            Layout.alignment: Qt.AlignVCenter
            processName: "hyprsunset"
            glyphOn: 0xF1A4C
            glyphOff: 0xF1A4D
            colOn: Theme.colYellow
            colOff: Theme.colMuted
        }

        BarSeparator { Layout.alignment: Qt.AlignVCenter }

        // idle manager
        ProcessToggle {
            Layout.alignment: Qt.AlignVCenter
            processName: "hypridle"
            glyphOn: 0xF04B2
            glyphOff: 0xF04B3
            colOn: Theme.colCyan
            colOff: Theme.colMuted
        }

        // Tied to the battery's own visibility: on machines with no battery
        // (visible: false, above), this would otherwise still draw and leave
        // a doubled-up separator next to the one before the clock.
        BarSeparator {
            Layout.alignment: Qt.AlignVCenter
            visible: battery.available
        }

        BatteryIndicator {
            id: battery
            Layout.alignment: Qt.AlignVCenter
        }

        BarSeparator { Layout.alignment: Qt.AlignVCenter }

        // Hovering it opens a day-of-week + month-calendar popover; see
        // Clock.qml.
        Clock {
            Layout.alignment: Qt.AlignVCenter
        }

        BarSeparator { Layout.alignment: Qt.AlignVCenter }

        PowerMenu {
            Layout.alignment: Qt.AlignVCenter
        }

        BarSeparator { Layout.alignment: Qt.AlignVCenter }

        NotificationHistoryButton {
            Layout.alignment: Qt.AlignVCenter
            open: notificationHistory.open
            historyCount: notifications.history.length
            onToggleRequested: notificationHistory.toggle()
        }
    }
}
