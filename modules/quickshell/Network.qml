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

    // The scanner starts first, so the networks Quickshell already knows are
    // listed as the panel builds and it opens at its full height.
    function openPanel() {
        if (wifi)
            wifi.scannerEnabled = true;
        panel.active = true;
    }

    visible: Stats.sampled
    lit: panel.active
    tooltip: [detail === "" ? name : `${name}, ${detail}`].concat(Vpn.active.map(p => `VPN: ${p.name}`)).join("\n")
    onClicked: button => {
        if (button === Qt.LeftButton) {
            if (panel.active)
                panel.item.close();
            else
                openPanel();
        } else if (button === Qt.RightButton)
            Launcher.run([Programs.nmConnectionEditor]);
    }

    component Direction: Row {
        property alias icon: arrow.text
        property alias values: spark.values
        // As Stats formats it: a figure, a space, a unit.
        property string rate

        anchors.verticalCenter: parent.verticalCenter
        visible: !Stats.offline
        leftPadding: 4
        spacing: 6

        BarText {
            id: arrow

            anchors.verticalCenter: parent.verticalCenter
            color: Theme.foregroundMuted
        }

        Spark {
            id: spark

            anchors.bottom: figure.baseline
            height: 20
        }

        Figure {
            id: figure

            anchors.verticalCenter: parent.verticalCenter
            widest: "999"
            horizontalAlignment: Text.AlignRight
            text: parent.rate.split(" ")[0]
        }

        // A slot as wide as the widest unit.
        Caption {
            id: units

            visible: false
            text: ["b/s", "Kb/s", "Mb/s", "Gb/s"].join("\n")
        }

        Caption {
            anchors.baseline: figure.baseline
            width: units.implicitWidth
            text: parent.rate.split(" ")[1] ?? ""
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

    // A join from this module's panel failed: reopen it to ask again.
    Connections {
        target: WifiJoin

        function onFailed(origin) {
            if (origin === network && !panel.active)
                network.openPanel();
        }
    }

    // Built on opening, so the bar scans for networks only while it is open.
    LazyLoader {
        id: panel

        NetworkPanel {
            module: network
            onDismissed: panel.active = false
        }
    }
}
