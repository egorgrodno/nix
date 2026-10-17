import QtQuick
import Quickshell
import Quickshell.Networking

// The connection, a VPN shield where a VPN profile exists, then upload and
// download, each a minute of history beside its rate. Click opens the network
// panel, right-click nm-connection-editor.
Pill {
    id: network

    readonly property WifiDevice wifi: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property WiredDevice wired: Networking.devices.values.find(d => d.type === DeviceType.Wired) ?? null
    // The device Stats reads, and the Wi-Fi network it is on.
    readonly property NetworkDevice device: Stats.networkDevice
    readonly property WifiNetwork wifiNetwork: device?.type === DeviceType.Wifi ? device.networks.values.find(n => n.connected) ?? null : null
    readonly property bool wifiOff: !device && wifi !== null && !Networking.wifiEnabled
    readonly property bool limited: Networking.connectivity === NetworkConnectivity.Limited || Networking.connectivity === NetworkConnectivity.Portal
    readonly property string glyph: {
        if (device?.type === DeviceType.Wired)
            return "\u{F0200}";
        if (device)
            return strengthGlyph(wifiNetwork?.signalStrength ?? 0);
        if (wifiOff)
            return "\u{F05AA}";
        return wifi ? "\u{F092E}" : "\u{F0202}";
    }
    readonly property color glyphColor: wifiOff ? Theme.foregroundDark : !device || limited ? Theme.yellow : "#ffffff"
    readonly property string name: wifiNetwork?.name ?? (device ? "Ethernet" : wifiOff ? "Wi-Fi off" : "No network")
    readonly property string detail: {
        const parts = [];
        if (wifiNetwork)
            parts.push(`${Math.round(wifiNetwork.signalStrength * 100)}%`);
        else if (device?.type === DeviceType.Wired && device.linkSpeed > 0)
            parts.push(`${device.linkSpeed} Mb/s`);
        if (device && limited)
            parts.push(Networking.connectivity === NetworkConnectivity.Portal ? "Captive portal" : "Limited connectivity");
        return parts.join(" · ");
    }

    // NetworkManager's applet's steps.
    function bars(signal) {
        return signal > 0.8 ? 4 : signal > 0.55 ? 3 : signal > 0.3 ? 2 : 1;
    }

    function strengthGlyph(signal) {
        return ["\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}"][bars(signal) - 1];
    }

    visible: Stats.sampled
    lit: panel.active
    tooltip: [detail === "" ? name : `${name}, ${detail}`].concat(Vpn.active.map(p => `VPN: ${p.name}`)).join("\n")
    onClicked: button => {
        if (button === Qt.LeftButton)
            panel.active = !panel.active;
        else if (button === Qt.RightButton)
            Quickshell.execDetached([Programs.nmConnectionEditor]);
    }

    component Direction: Row {
        property alias icon: arrow.text
        property alias values: spark.values
        property alias rate: figure.text

        anchors.verticalCenter: parent.verticalCenter
        visible: !Stats.offline
        spacing: 4

        BarText {
            id: arrow

            anchors.verticalCenter: parent.verticalCenter
            color: Theme.foregroundMuted
            font.pixelSize: 12
        }

        Spark {
            id: spark

            anchors.verticalCenter: parent.verticalCenter
        }

        Figure {
            id: figure

            anchors.verticalCenter: parent.verticalCenter
            widest: "999 Kb/s"
        }
    }

    // Slots as wide as the widest glyph each can show, measured as on the
    // volume module.
    BarText {
        id: glyphs

        visible: false
        text: ["\u{F0200}", "\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}", "\u{F05AA}", "\u{F092E}", "\u{F0202}"].join("\n")
    }

    BarText {
        id: shields

        visible: false
        text: "\u{F099D}\n\u{F0CCC}"
    }

    BarText {
        anchors.verticalCenter: parent.verticalCenter
        width: glyphs.implicitWidth
        horizontalAlignment: Text.AlignHCenter
        text: network.glyph
        color: network.glyphColor
    }

    BarText {
        anchors.verticalCenter: parent.verticalCenter
        visible: Vpn.profiles.length > 0
        width: shields.implicitWidth
        horizontalAlignment: Text.AlignHCenter
        text: Vpn.active.length > 0 ? "\u{F099D}" : "\u{F0CCC}"
        color: Vpn.active.length > 0 ? Theme.blue : Theme.foregroundDark
    }

    BarText {
        anchors.verticalCenter: parent.verticalCenter
        visible: Stats.offline
        text: network.wifiOff ? "Wi-Fi off" : "No network"
        color: network.wifiOff ? Theme.foregroundMuted : Theme.yellow
    }

    Direction {
        icon: "\u{F0737}"
        values: Stats.upHistory
        rate: Stats.up
    }

    Direction {
        icon: "\u{F072E}"
        values: Stats.downHistory
        rate: Stats.down
    }

    // Built on opening, so the bar scans for networks only while it is open.
    LazyLoader {
        id: panel

        NetworkPanel {
            module: network
            onVisibleChanged: if (!visible)
                panel.active = false
        }
    }
}
