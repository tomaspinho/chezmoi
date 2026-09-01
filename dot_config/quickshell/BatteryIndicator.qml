import Quickshell
import Quickshell.Services.UPower
import QtQuick

Row {
    id: bat

    // UPower's aggregate battery. Like Networking, it isn't ready for a few
    // seconds after startup, so these stay live bindings.
    readonly property var device: UPower.displayDevice

    readonly property bool available: (device?.ready ?? false)
        && (device?.isPresent ?? false)
        && (device?.isLaptopBattery ?? false)

    // percentage comes through as a 0-1 fraction
    readonly property int percent: Math.round((device?.percentage ?? 0) * 100)

    readonly property bool charging: device?.state === UPowerDeviceState.Charging
        || device?.state === UPowerDeviceState.PendingCharge
    readonly property bool full: device?.state === UPowerDeviceState.FullyCharged

    // 0% -> 100% in 10% steps. The per-level *charging* glyphs are unreliable in
    // this font (F08A0 is a bed, F08A1+ are missing), so charging just gets the
    // one bolt glyph and the level is read off the percentage.
    readonly property var levels: ["󰂎", "󰁺", "󰁻", "󰁼", "󰁽", "󰁾", "󰁿", "󰂀", "󰂁", "󰂂", "󰁹"]

    readonly property color tint: charging || full ? Theme.colGreen
        : percent <= 15 ? Theme.colRed
        : percent <= 30 ? Theme.colYellow
        : Theme.colFg

    // hidden on machines with no battery
    visible: available
    spacing: 5

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: bat.charging ? "󰂄" : bat.levels[Math.round(bat.percent / 10)]
        color: bat.tint
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
    }

    Text {
        anchors.verticalCenter: parent.verticalCenter
        text: `${bat.percent}%`
        color: bat.tint
        font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
    }
}
