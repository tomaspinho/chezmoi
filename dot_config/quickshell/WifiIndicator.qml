import Quickshell
import Quickshell.Hyprland
import Quickshell.Networking
import QtQuick
import QtQuick.Controls

Item {
    id: wifi

    property color colBg: "#1a1b26"
    property color colFg: "#a9b1d6"
    property color colMuted: "#444b6a"
    property color colCyan: "#0db9d7"
    property color colBlue: "#7aa2f7"
    property color colYellow: "#e0af68"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14

    // Networking populates over dbus a few seconds after startup, so everything
    // here has to stay a live binding rather than a one-shot lookup.
    readonly property var device: {
        for (const d of Networking.devices.values)
            if (d.type === DeviceType.Wifi) return d;
        return null;
    }

    readonly property var active: {
        if (!device) return null;
        for (const n of device.networks.values)
            if (n.connected) return n;
        return null;
    }

    // This desktop has no Wi-Fi to speak of and connects over ethernet
    // instead, so the bar icon (and this popup) cover wired too. There's at
    // most one wired device/profile, unlike the list of Wi-Fi networks above.
    readonly property var wiredDevice: {
        for (const d of Networking.devices.values)
            if (d.type === DeviceType.Wired) return d;
        return null;
    }

    readonly property var wiredNetwork: wiredDevice?.network ?? null
    readonly property bool wiredConnected: wiredDevice?.connected ?? false

    // md-ethernet. No signal-strength concept for a wire, so unlike Wi-Fi
    // this is the one glyph for the connected state; colour carries the rest.
    readonly property string ethernetGlyph: "󰈀"

    // One entry per SSID (keep the strongest AP), connected first, then saved.
    readonly property var networks: {
        if (!device) return [];
        const best = new Map();
        for (const n of device.networks.values) {
            if (!n.name) continue;
            const prev = best.get(n.name);
            if (!prev || n.connected
                || (!prev.connected && n.signalStrength > prev.signalStrength))
                best.set(n.name, n);
        }
        return Array.from(best.values()).sort((a, b) => {
            if (a.connected !== b.connected) return a.connected ? -1 : 1;
            if (a.known !== b.known) return a.known ? -1 : 1;
            return b.signalStrength - a.signalStrength;
        });
    }

    readonly property var bars: ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]

    function barsFor(strength) {
        return bars[Math.min(4, Math.floor(strength * 4) + 1)];
    }

    function isOpen(network) {
        return network.security === WifiSecurityType.Open
            || network.security === WifiSecurityType.Owe;
    }

    property bool expanded: false

    // Only scan while the user is actually looking at the list.
    Binding {
        target: wifi.device
        property: "scannerEnabled"
        value: wifi.expanded
        when: wifi.device !== null
    }

    implicitWidth: icon.implicitWidth
    implicitHeight: icon.implicitHeight

    Text {
        id: icon
        anchors.centerIn: parent
        // +4: these glyphs (esp. the outline/no-signal ones) are drawn much
        // smaller within their cell than the other bar icons, so they read
        // as noticeably smaller at the same pixelSize.
        font { family: wifi.fontFamily; pixelSize: wifi.fontSize + 4 }
        // Wi-Fi takes precedence when both are connected - it's the link
        // that's actually more likely to drop, so it's the one worth a
        // glance at. Wired-but-not-connected still beats a bare "off" glyph:
        // a plugged-in, dead cable is more useful to know about than nothing.
        color: wifi.active ? wifi.colCyan
            : wifi.wiredConnected ? wifi.colCyan
            : Networking.wifiEnabled ? wifi.colYellow
            : wifi.colMuted
        text: wifi.active ? wifi.barsFor(wifi.active.signalStrength)
            : wifi.wiredConnected ? wifi.ethernetGlyph
            : Networking.wifiEnabled ? "󰤯"
            : wifi.wiredDevice ? wifi.ethernetGlyph
            : "󰤮"
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            wifi.expanded = !wifi.expanded;
            if (!wifi.expanded) popup.pending = null;
        }
    }

    HyprlandFocusGrab {
        active: wifi.expanded
        windows: [popup]
        onCleared: popup.close()
    }

    PopupWindow {
        id: popup

        // network awaiting a password, if any
        property var pending: null
        property string error: ""

        function close() {
            wifi.expanded = false;
            pending = null;
        }

        function activate(network) {
            error = "";
            if (network.connected) {
                network.disconnect();
                return;
            }
            if (network.known || wifi.isOpen(network)) {
                network.connect();
                close();
                return;
            }
            pending = network;
        }

        anchor {
            item: wifi
            edges: Edges.Bottom
            gravity: Edges.Bottom | Edges.Left
            margins.top: 6
        }

        color: "transparent"
        visible: wifi.expanded
        implicitWidth: 300
        implicitHeight: frame.implicitHeight

        Rectangle {
            id: frame
            anchors.fill: parent
            implicitHeight: content.implicitHeight + 16
            color: wifi.colBg
            radius: 8
            border { width: 1; color: wifi.colMuted }

            Column {
                id: content
                anchors { fill: parent; margins: 8 }
                spacing: 2

                Item {
                    width: parent.width
                    height: 24

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Wi-Fi"
                        color: wifi.colFg
                        font { family: wifi.fontFamily; pixelSize: wifi.fontSize; bold: true }
                    }

                    Text {
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: Networking.wifiEnabled ? "󰖩 on" : "󰖪 off"
                        color: Networking.wifiEnabled ? wifi.colCyan : wifi.colMuted
                        font { family: wifi.fontFamily; pixelSize: wifi.fontSize - 2 }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: Networking.wifiHardwareEnabled
                            onClicked: Networking.wifiEnabled = !Networking.wifiEnabled
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: wifi.colMuted
                }

                Text {
                    width: parent.width
                    visible: wifi.networks.length === 0
                    padding: 6
                    text: !Networking.wifiEnabled ? "Wi-Fi is off"
                        : !wifi.device ? "No Wi-Fi device" : "Scanning…"
                    color: wifi.colMuted
                    font { family: wifi.fontFamily; pixelSize: wifi.fontSize - 2 }
                }

                ListView {
                    width: parent.width
                    height: Math.min(contentHeight, 260)
                    clip: true
                    model: wifi.networks
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        required property var modelData

                        width: ListView.view.width
                        height: 26
                        radius: 4
                        color: hover.hovered ? Qt.lighter(wifi.colBg, 1.6) : "transparent"

                        Text {
                            id: rowBars
                            anchors { left: parent.left; leftMargin: 6; verticalCenter: parent.verticalCenter }
                            text: wifi.barsFor(modelData.signalStrength)
                            color: modelData.connected ? wifi.colCyan : wifi.colMuted
                            font { family: wifi.fontFamily; pixelSize: wifi.fontSize }
                        }

                        Text {
                            anchors {
                                left: rowBars.right; leftMargin: 8
                                right: rowState.left; rightMargin: 6
                                verticalCenter: parent.verticalCenter
                            }
                            text: modelData.name + (wifi.isOpen(modelData) ? "" : " 󰌾")
                            elide: Text.ElideRight
                            color: modelData.connected ? wifi.colCyan
                                : modelData.known ? wifi.colBlue : wifi.colFg
                            font { family: wifi.fontFamily; pixelSize: wifi.fontSize - 2 }
                        }

                        Text {
                            id: rowState
                            anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                            text: modelData.stateChanging ? "…"
                                : modelData.connected ? "󰄬" : ""
                            color: wifi.colCyan
                            font { family: wifi.fontFamily; pixelSize: wifi.fontSize - 2 }
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
                                    if (modelData.known) modelData.forget();
                                } else {
                                    popup.activate(modelData);
                                }
                            }
                        }

                        Connections {
                            target: modelData
                            function onConnectionFailed(reason) {
                                popup.error = `${modelData.name}: ${ConnectionFailReason.toString(reason)}`;
                                popup.pending = modelData;
                            }
                        }
                    }
                }

                Item {
                    width: parent.width
                    height: popup.pending ? 30 : 0
                    visible: popup.pending !== null

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 4
                        color: Qt.lighter(wifi.colBg, 1.6)
                        radius: 4

                        TextField {
                            id: psk
                            anchors.fill: parent
                            leftPadding: 8
                            rightPadding: 8
                            echoMode: TextInput.Password
                            placeholderText: qsTr("Password for %1").arg(popup.pending?.name ?? "")
                            placeholderTextColor: wifi.colMuted
                            color: wifi.colFg
                            font { family: wifi.fontFamily; pixelSize: wifi.fontSize - 2 }
                            background: null

                            // grab the keyboard as soon as a password is asked for
                            onVisibleChanged: if (visible) forceActiveFocus()
                            Component.onCompleted: if (visible) forceActiveFocus()

                            onAccepted: {
                                popup.pending.connectWithPsk(text);
                                text = "";
                                popup.close();
                            }
                            Keys.onEscapePressed: {
                                text = "";
                                popup.pending = null;
                            }
                        }
                    }
                }

                Text {
                    width: parent.width
                    visible: popup.error !== ""
                    padding: 4
                    text: popup.error
                    wrapMode: Text.Wrap
                    color: wifi.colYellow
                    font { family: wifi.fontFamily; pixelSize: wifi.fontSize - 3 }
                }

                // Wired has at most one device/profile, so it gets a single
                // compact row rather than a whole section like Wi-Fi's list -
                // and it's hidden entirely on machines with no ethernet port.
                Rectangle {
                    width: parent.width
                    height: 1
                    visible: wifi.wiredDevice !== null
                    color: wifi.colMuted
                }

                Item {
                    width: parent.width
                    height: 24
                    visible: wifi.wiredDevice !== null

                    Text {
                        anchors { left: parent.left; right: ethState.left; rightMargin: 6; verticalCenter: parent.verticalCenter }
                        elide: Text.ElideRight
                        text: wifi.ethernetGlyph + "  " + (wifi.wiredNetwork?.name ?? wifi.wiredDevice?.name ?? "Ethernet")
                        color: wifi.wiredConnected ? wifi.colCyan : wifi.colFg
                        font { family: wifi.fontFamily; pixelSize: wifi.fontSize - 2 }
                    }

                    Text {
                        id: ethState
                        anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                        text: wifi.wiredDevice && !wifi.wiredDevice.hasLink ? "unplugged"
                            : wifi.wiredNetwork?.stateChanging ? "…"
                            : wifi.wiredConnected ? "on" : "off"
                        color: wifi.wiredConnected ? wifi.colCyan : wifi.colMuted
                        font { family: wifi.fontFamily; pixelSize: wifi.fontSize - 2 }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            enabled: wifi.wiredNetwork !== null && wifi.wiredDevice.hasLink
                            onClicked: wifi.wiredConnected ? wifi.wiredNetwork.disconnect() : wifi.wiredNetwork.connect()
                        }
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: wifi.colMuted
                }

                // Same launch-and-close pattern VolumeIndicator uses for
                // pavucontrol: NetworkManager's own connection editor covers
                // everything this popup doesn't (VPNs, static IPs, profiles).
                Rectangle {
                    width: parent.width
                    height: 24
                    radius: 4
                    color: settingsHover.hovered ? Qt.lighter(wifi.colBg, 1.8) : "transparent"
                    border { width: 1; color: wifi.colMuted }

                    Text {
                        anchors.centerIn: parent
                        text: "Network settings"
                        color: settingsHover.hovered ? wifi.colCyan : wifi.colFg
                        font { family: wifi.fontFamily; pixelSize: wifi.fontSize - 3 }
                    }

                    HoverHandler {
                        id: settingsHover
                        // See the row delegate above: the cursor has to come
                        // from the hover handler, not the TapHandler.
                        cursorShape: Qt.PointingHandCursor
                    }

                    TapHandler {
                        onTapped: {
                            Hyprland.dispatch('hl.dsp.exec_cmd("[float] nm-connection-editor")');
                            popup.close();
                        }
                    }
                }
            }
        }
    }
}
