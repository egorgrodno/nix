import QtQuick
import Quickshell.Networking

// The network tooltip: the connection and its channel, the signal and both
// rates over five minutes, the addresses with the round trips to the gateway
// and the internet, and any VPN up.
Column {
    id: tip

    // The network module, which names the connection.
    required property Item module
    readonly property NetworkDevice device: Stats.networkDevice
    readonly property bool wifi: device?.type === DeviceType.Wifi
    readonly property var link: Stats.link
    // [label, address, the ping that times it], a row without an address
    // hidden.
    readonly property var addresses: [["IPv4", link.ipv4?.[0] ?? "", null], ["IPv6", link.ipv6?.[0] ?? "", null], ["Gateway", link.gateway ?? "", gateway], ["DNS", (link.dns ?? []).join(", "), null], ["Internet", internet.host, internet]]

    function latency(ping) {
        if (!ping)
            return "";
        if (!ping.replied)
            return "no reply";
        return isNaN(ping.rtt) ? "" : `${ping.rtt < 10 ? ping.rtt.toFixed(1) : Math.round(ping.rtt)} ms`;
    }

    spacing: 12

    Poll {
        onPoll: {
            if (!tip.device)
                return;
            Stats.sampleLink();
            gateway.send();
            internet.send();
        }
    }

    Ping {
        id: gateway

        host: tip.link.gateway ?? ""
    }

    Ping {
        id: internet

        host: "1.1.1.1"
    }

    // Slots as wide as the widest label and the widest address.
    BarText {
        id: labels

        visible: false
        text: ["Up", "Down"].concat(tip.addresses.map(a => a[0])).join("\n")
        font.pixelSize: 14
    }

    BarText {
        id: values

        visible: false
        text: tip.addresses.map(a => a[1]).join("\n")
        font.family: Theme.fontMono
        font.pixelSize: 14
    }

    BarText {
        visible: tip.device === null
        text: tip.module.name
    }

    Column {
        visible: tip.device !== null
        spacing: 2

        BarText {
            text: tip.module.name
        }

        Facts {
            parts: {
                const l = tip.link;
                const parts = tip.wifi ? [[l.band, l.channel ? `channel ${l.channel}` : "", l.width].filter(s => s).join(", "), l.security === undefined ? "" : l.security === "" ? "Open" : l.security.replace(/ /g, "/"), isNaN(l.maxRate) ? "" : `up to ${l.maxRate} Mbit/s`] : [tip.device?.name ?? "", isNaN(l.speed) ? "" : `${l.speed} Mbit/s`, l.duplex ? `${l.duplex} duplex` : ""];
                if (tip.module.limited)
                    parts.push({
                        text: Networking.connectivity === NetworkConnectivity.Portal ? "Captive portal" : "Limited connectivity",
                        color: Theme.yellow
                    });
                return parts;
            }
        }
    }

    // The figure in the label column, so the spark lines up with the rates'.
    Row {
        visible: tip.wifi
        spacing: 8

        Figure {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(labels.implicitWidth, implicitWidth)
            text: `${Math.round(100 * (Stats.wifiNetwork?.signalStrength ?? 0))}%`
        }

        Spark {
            anchors.verticalCenter: parent.verticalCenter
            width: 120
            height: 24
            samples: 150
            floor: 100
            values: Stats.signalHistory
        }

        Facts {
            anchors.verticalCenter: parent.verticalCenter
            parts: [isNaN(tip.link.dbm) ? "" : {
                    text: Math.round(tip.link.dbm),
                    widest: "-00",
                    suffix: " dBm"
                }, isNaN(tip.link.speed) ? "" : {
                    text: tip.link.speed,
                    widest: "000",
                    suffix: " Mbit/s"
                }, isNaN(tip.link.failed) ? "" : `${tip.link.failed} failed ${tip.link.failed === 1 ? "send" : "sends"}`]
        }
    }

    Column {
        visible: tip.device !== null
        spacing: 4

        Repeater {
            model: [["Up", "up"], ["Down", "down"]]

            Row {
                id: direction

                required property var modelData
                readonly property var history: Stats[`${modelData[1]}History`]

                spacing: 8

                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: labels.implicitWidth
                    text: direction.modelData[0]
                    color: Theme.foregroundMuted
                    font.pixelSize: 14
                }

                Spark {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 120
                    height: 18
                    samples: 150
                    values: direction.history
                }

                Figure {
                    anchors.verticalCenter: parent.verticalCenter
                    widest: "000 Kb/s"
                    horizontalAlignment: Text.AlignRight
                    text: Stats[direction.modelData[1]]
                    font.pixelSize: 14
                }

                Facts {
                    anchors.verticalCenter: parent.verticalCenter
                    parts: direction.history.length > 0 ? [{
                            prefix: "peak ",
                            text: Stats.rate(Math.max(...direction.history)),
                            widest: "000 Kb/s"
                        }] : []
                }
            }
        }
    }

    Column {
        visible: tip.device !== null
        spacing: 4

        Repeater {
            model: tip.addresses.length

            Row {
                id: address

                required property int index
                readonly property var row: tip.addresses[index]

                visible: row[1] !== ""
                spacing: 8

                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    width: labels.implicitWidth
                    text: address.row[0]
                    color: Theme.foregroundMuted
                    font.pixelSize: 14
                }

                Figure {
                    anchors.verticalCenter: parent.verticalCenter
                    width: values.implicitWidth
                    text: address.row[1]
                    font.pixelSize: 14
                }

                Figure {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: address.row[2] !== null
                    widest: "no reply"
                    horizontalAlignment: Text.AlignRight
                    text: tip.latency(address.row[2])
                    color: address.row[2]?.replied === false ? Theme.yellow : Theme.foregroundMuted
                    font.pixelSize: 14
                }
            }
        }
    }

    Column {
        visible: Vpn.active.length > 0
        spacing: 2

        Repeater {
            model: Vpn.active

            Facts {
                required property var modelData

                parts: [`VPN: ${modelData.name}`, modelData.type === "wireguard" ? "WireGuard" : ""]
            }
        }
    }
}
