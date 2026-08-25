import Quickshell
import Quickshell.Hyprland
import Quickshell.Networking
import Quickshell.Io
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

    // ip/gateway per kernel interface name (device.name is that name, e.g.
    // "enp6s0"/"wlp5s0" - confirmed against the same machine's `nmcli
    // device status`), not exposed by Quickshell.Networking itself. Cheap
    // enough that it just runs on a plain timer while the popup is open,
    // rather than needing the scanner's tighter enable-on-expand gating.
    property var ifaceAddress: ({})
    property var ifaceGateway: ({})

    function hostIpFor(ifname) { return ifname ? (wifi.ifaceAddress[ifname] ?? "") : ""; }
    function gatewayIpFor(ifname) { return ifname ? (wifi.ifaceGateway[ifname] ?? "") : ""; }

    Timer {
        interval: 5000
        running: wifi.expanded
        repeat: true
        triggeredOnStart: true
        onTriggered: { addrProc.running = true; routeProc.running = true; }
    }

    Process {
        id: addrProc
        command: ["ip", "-j", "addr", "show", "scope", "global"]
        stdout: StdioCollector {
            onStreamFinished: {
                const result = {};
                try {
                    for (const iface of JSON.parse(text)) {
                        const inet = (iface.addr_info ?? []).find(a => a.family === "inet");
                        if (inet) result[iface.ifname] = `${inet.local}/${inet.prefixlen}`;
                    }
                } catch (e) { /* malformed/empty output between interface changes - keep the old map */ }
                wifi.ifaceAddress = result;
            }
        }
    }

    Process {
        id: routeProc
        // Only the default route's interface gets a gateway shown - a
        // secondary/non-default route's gateway isn't what's actually
        // carrying this machine's traffic.
        command: ["ip", "-j", "route", "show", "default"]
        stdout: StdioCollector {
            onStreamFinished: {
                const result = {};
                try {
                    for (const route of JSON.parse(text))
                        if (route.dev && route.gateway) result[route.dev] = route.gateway;
                } catch (e) { /* see addrProc */ }
                wifi.ifaceGateway = result;
            }
        }
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
                        // Only the connected network has an interface to
                        // report on; everything else was never assigned one.
                        readonly property string hostIp:
                            modelData.connected ? wifi.hostIpFor(wifi.device?.name) : ""
                        readonly property string gatewayIp:
                            modelData.connected ? wifi.gatewayIpFor(wifi.device?.name) : ""

                        width: ListView.view.width
                        height: hostIp !== "" ? 58 : 26
                        radius: 4
                        color: hover.hovered ? Qt.lighter(wifi.colBg, 1.6) : "transparent"

                        Text {
                            id: rowBars
                            anchors { left: parent.left; leftMargin: 6; top: parent.top; topMargin: 5 }
                            text: wifi.barsFor(modelData.signalStrength)
                            color: modelData.connected ? wifi.colCyan : wifi.colMuted
                            font { family: wifi.fontFamily; pixelSize: wifi.fontSize }
                        }

                        Text {
                            anchors {
                                left: rowBars.right; leftMargin: 8
                                right: rowState.left; rightMargin: 6
                                top: parent.top; topMargin: 5
                            }
                            text: modelData.name + (wifi.isOpen(modelData) ? "" : " 󰌾")
                            elide: Text.ElideRight
                            color: modelData.connected ? wifi.colCyan
                                : modelData.known ? wifi.colBlue : wifi.colFg
                            font { family: wifi.fontFamily; pixelSize: wifi.fontSize - 2 }
                        }

                        Text {
                            id: rowState
                            anchors { right: parent.right; rightMargin: 6; top: parent.top; topMargin: 5 }
                            text: modelData.stateChanging ? "…"
                                : modelData.connected ? "󰄬" : ""
                            color: wifi.colCyan
                            font { family: wifi.fontFamily; pixelSize: wifi.fontSize - 2 }
                        }

                        Text {
                            anchors { left: rowBars.right; leftMargin: 8; right: parent.right; rightMargin: 6; top: parent.top; topMargin: 23 }
                            visible: parent.hostIp !== ""
                            elide: Text.ElideRight
                            text: "Host IP: " + (parent.hostIp ?? "")
                            color: wifi.colMuted
                            font { family: wifi.fontFamily; pixelSize: wifi.fontSize - 3 }
                        }

                        Text {
                            anchors { left: rowBars.right; leftMargin: 8; right: parent.right; rightMargin: 6; top: parent.top; topMargin: 39 }
                            visible: parent.gatewayIp !== ""
                            elide: Text.ElideRight
                            text: "Gateway IP: " + (parent.gatewayIp ?? "")
                            color: wifi.colMuted
                            font { family: wifi.fontFamily; pixelSize: wifi.fontSize - 3 }
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

                Text {
                    width: parent.width
                    visible: wifi.networks.length > 0
                    padding: 4
                    // scannerEnabled is what this file itself drives (tied
                    // to wifi.expanded above) rather than a true "scan in
                    // progress right now" signal, but it's the closest
                    // analog Quickshell.Networking exposes to Bluetooth's
                    // adapter.discovering.
                    text: (wifi.device?.scannerEnabled ?? false) ? "Scanning…  ·  right-click to forget"
                        : "right-click to forget"
                    color: wifi.colMuted
                    font { family: wifi.fontFamily; pixelSize: wifi.fontSize - 4 }
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
                                // Clears the password field rather than
                                // closing the whole popup (popup.close()),
                                // so the list stays open to actually show
                                // the row going through its connecting
                                // state to the checkmark - or, via the
                                // connectionFailed handler below, back to
                                // this same password prompt on failure.
                                popup.pending.connectWithPsk(text);
                                text = "";
                                popup.pending = null;
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
                // Taller than a bare separator (with the line kept at the
                // bottom) so there's a clearer gap between the Wi-Fi list
                // above and the wired section below than the Column's
                // regular spacing gives every other row pair.
                Item {
                    width: parent.width
                    height: 10
                    visible: wifi.wiredDevice !== null

                    Rectangle {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                        height: 1
                        color: wifi.colMuted
                    }
                }

                Item {
                    id: wiredRow
                    width: parent.width
                    readonly property string hostIp: wifi.hostIpFor(wifi.wiredDevice?.name)
                    readonly property string gatewayIp: wifi.gatewayIpFor(wifi.wiredDevice?.name)
                    // Tall enough for the IP/gateway rows only when there's
                    // actually something to show (i.e. connected).
                    height: wiredRow.hostIp !== "" ? 56 : 24
                    visible: wifi.wiredDevice !== null

                    Text {
                        id: wiredIcon
                        anchors { left: parent.left; top: parent.top; topMargin: 4 }
                        text: wifi.ethernetGlyph
                        color: wifi.wiredConnected ? wifi.colCyan : wifi.colFg
                        font { family: wifi.fontFamily; pixelSize: wifi.fontSize - 2 }
                    }

                    Text {
                        // Same left anchor (wiredIcon.right + 8) as the IP
                        // rows below, so the name and the labels underneath
                        // it line up exactly - same pattern as the Wi-Fi
                        // list delegate's rowBars/name/IP-row anchors.
                        anchors { left: wiredIcon.right; leftMargin: 8; right: ethState.left; rightMargin: 6; top: parent.top; topMargin: 4 }
                        elide: Text.ElideRight
                        text: wifi.wiredNetwork?.name ?? wifi.wiredDevice?.name ?? "Ethernet"
                        color: wifi.wiredConnected ? wifi.colCyan : wifi.colFg
                        font { family: wifi.fontFamily; pixelSize: wifi.fontSize - 2 }
                    }

                    Text {
                        id: ethState
                        anchors { right: parent.right; top: parent.top; topMargin: 4 }
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

                    Text {
                        anchors { left: wiredIcon.right; leftMargin: 8; right: parent.right; top: parent.top; topMargin: 22 }
                        visible: wiredRow.hostIp !== ""
                        elide: Text.ElideRight
                        text: "Host IP: " + wiredRow.hostIp
                        color: wifi.colMuted
                        font { family: wifi.fontFamily; pixelSize: wifi.fontSize - 3 }
                    }

                    Text {
                        anchors { left: wiredIcon.right; leftMargin: 8; right: parent.right; top: parent.top; topMargin: 38 }
                        visible: wiredRow.gatewayIp !== ""
                        elide: Text.ElideRight
                        text: "Gateway IP: " + wiredRow.gatewayIp
                        color: wifi.colMuted
                        font { family: wifi.fontFamily; pixelSize: wifi.fontSize - 3 }
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
