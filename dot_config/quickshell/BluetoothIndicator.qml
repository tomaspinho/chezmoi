import Quickshell
import Quickshell.Bluetooth
import Quickshell.Hyprland
import QtQuick

Item {
    id: bt


    property bool expanded: false

    // Bluez comes up over dbus a few seconds after startup, so these stay live
    // bindings rather than one-shot lookups.
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool enabled: adapter?.enabled ?? false

    readonly property var connectedDevices: Bluetooth.devices.values.filter(d => d.connected)

    // Discovery turns up plenty of nameless BLE beacons; only offer devices we
    // can actually label, plus anything already known to the adapter.
    function isAnonymous(device) {
        const n = (device.name ?? "").trim();
        if (n === "") return true;
        return n.replace(/[-:]/g, "").toUpperCase()
            === (device.address ?? "").replace(/:/g, "").toUpperCase();
    }

    readonly property var devices: {
        if (!enabled) return [];
        return Bluetooth.devices.values
            .filter(d => d.paired || d.bonded || !isAnonymous(d))
            .sort((a, b) => {
                if (a.connected !== b.connected) return a.connected ? -1 : 1;
                const aKnown = a.paired || a.bonded;
                const bKnown = b.paired || b.bonded;
                if (aKnown !== bKnown) return aKnown ? -1 : 1;
                return (a.name ?? "").localeCompare(b.name ?? "");
            });
    }

    // freedesktop icon name -> nerd font codepoint
    readonly property var glyphs: ({
        "audio-headset": 0xF02CB,
        "audio-headphones": 0xF02CB,
        "audio-card": 0xF04C3,
        "input-mouse": 0xF037D,
        "input-keyboard": 0xF030C,
        "input-gaming": 0xF0EB5,
        "phone": 0xF03F2,
        "computer": 0xF0322,
        "video-display": 0xF0839,
        "printer": 0xF042A
    })

    function glyphFor(device) {
        return String.fromCodePoint(glyphs[device.icon ?? ""] ?? 0xF00AF);
    }

    // Only scan while the menu is open.
    Binding {
        target: bt.adapter
        property: "discovering"
        value: bt.expanded && bt.enabled
        when: bt.adapter !== null
    }

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    BarIcon {
        id: icon
        anchors.centerIn: parent
        color: !bt.enabled ? Theme.colMuted
            : bt.connectedDevices.length > 0 ? Theme.colCyan : Theme.colBlue
        // bluetooth / bluetooth-off / bluetooth-connect
        glyph: String.fromCodePoint(!bt.enabled ? 0xF00B2
            : bt.connectedDevices.length > 0 ? 0xF00B1 : 0xF00AF)
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: bt.expanded = !bt.expanded
    }

    HyprlandFocusGrab {
        active: bt.expanded
        windows: [menu]
        onCleared: bt.expanded = false
    }

    BarPopup {
        id: menu
        anchorItem: bt
        visible: bt.expanded
        popupWidth: 290


        // device we started pairing, so it can be connected once pairing lands
        property var pairingWith: null

        function activate(device) {
            if (device.connected) {
        device.disconnect();
            } else if (device.paired || device.bonded) {
        device.connect();
            } else {
        pairingWith = device;
        device.pair();
            }
        }

        PopupHeader {
            title: "Bluetooth"
            on: bt.enabled
            toggleEnabled: bt.adapter !== null
            onToggled: bt.adapter.enabled = !bt.adapter.enabled
        }

        PopupDivider {}

        Text {
            width: parent.width
            visible: bt.devices.length === 0
            padding: 6
            text: !bt.adapter ? "No Bluetooth adapter"
                : !bt.enabled ? "Bluetooth is off" : "Scanning…"
            color: Theme.colMuted
            font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 2 }
        }

        ListView {
            width: parent.width
            height: Math.min(contentHeight, 260)
            clip: true
            model: bt.devices
            boundsBehavior: Flickable.StopAtBounds

            delegate: Rectangle {
                required property var modelData

                width: ListView.view.width
                height: 26
                radius: 4
                color: hover.hovered ? Qt.lighter(Theme.colBg, 1.6) : "transparent"

                Text {
                    id: devIcon
                    anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                    text: bt.glyphFor(modelData)
                    color: modelData.connected ? Theme.colCyan
                        : (modelData.paired || modelData.bonded) ? Theme.colBlue : Theme.colMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize }
                }

                Text {
                    anchors {
                        left: devIcon.right; leftMargin: 8
                        right: devState.left; rightMargin: 6
                        verticalCenter: parent.verticalCenter
                    }
                    text: modelData.name || modelData.address
                    elide: Text.ElideRight
                    color: modelData.connected ? Theme.colCyan
                        : (modelData.paired || modelData.bonded) ? Theme.colFg : Theme.colMuted
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 2 }
                }

                Text {
                    id: devState
                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    text: {
                        if (modelData.pairing) return "pairing…";
                        if (modelData.state === BluetoothDeviceState.Connecting) return "…";
                        if (modelData.state === BluetoothDeviceState.Disconnecting) return "…";
                        if (modelData.connected && modelData.batteryAvailable) {
                            // quickshell reports these as 0-1 fractions
                            const b = modelData.battery;
                            return `${Math.round(b <= 1 ? b * 100 : b)}%`;
                        }
                        if (modelData.connected) return "󰄬";
                        return "";
                    }
                    color: Theme.colCyan
                    font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 3 }
                }

                HoverHandler {
                    id: hover
                    // Not on the TapHandler: a pointer handler's
                    // cursorShape only applies while it is active,
                    // which for a tap is "while held", not "while
                    // hovered".
                    cursorShape: Qt.PointingHandCursor
                }

                TapHandler {
                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    onTapped: (event, button) => {
                        if (button === Qt.RightButton) {
                            if (modelData.paired || modelData.bonded) modelData.forget();
                        } else {
                            menu.activate(modelData);
                        }
                    }
                }

                // pairing is a separate step from connecting, so follow
                // through once the device is actually paired
                Connections {
                    target: modelData
                    function onPairedChanged() {
                        if (modelData.paired && menu.pairingWith === modelData) {
                            modelData.trusted = true;
                            modelData.connect();
                            menu.pairingWith = null;
                        }
                    }
                }
            }
        }

        Text {
            width: parent.width
            visible: bt.enabled && bt.devices.length > 0
            padding: 4
            text: (bt.adapter?.discovering ?? false) ? "Scanning…  ·  right-click to forget"
                : "right-click to forget"
            color: Theme.colMuted
            font { family: Theme.fontFamily; pixelSize: Theme.fontSize - 4 }
        }
    }
}
