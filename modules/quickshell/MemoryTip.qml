import QtQuick

// The memory tooltip: the modules, what is used, cached and free, swap, and
// the apps holding the most.
Column {
    id: tip

    readonly property var modules: Hardware.modules
    // Channels by the letter the firmware names them with, as `P0 CHANNEL A`
    // or `DIMM_A1`.
    readonly property int channels: new Set(modules.map(m => `${m.BANK_LOCATOR ?? ""} ${m.LOCATOR ?? ""}`.match(/CHANNEL\s*([A-H])\b|DIMM_?([A-H])\d/i)?.slice(1).find(c => c)?.toUpperCase()).filter(c => c)).size
    readonly property string title: {
        if (modules.length === 0)
            return `${Stats.size(Stats.memoryTotal)} memory`;
        const gib = Math.round(modules.reduce((sum, m) => sum + Number(m.SIZE), 0) / 1073741824);
        const speed = modules[0].CONFIGURED_SPEED_MTS ?? modules[0].SPEED_MTS;
        const kind = [modules[0].TYPE, speed].filter(s => s).join("-");
        return `${gib} GiB ${kind}`.trim();
    }
    readonly property string layout: {
        if (modules.length === 0)
            return "";
        const sizes = modules.map(m => Math.round(Number(m.SIZE) / 1073741824));
        const same = key => modules.every(m => m[key] === modules[0][key]) ? modules[0][key] ?? "" : "";
        const count = sizes.every(s => s === sizes[0]) ? `${modules.length} × ${sizes[0]} GiB` : `${sizes.join(" + ")} GiB`;
        return [count, same("MANUFACTURER"), same("FORM_FACTOR")].filter(s => s && s !== "Unknown").join(" ");
    }

    spacing: 12

    Poll {
        onPoll: {
            Stats.sampleMemory();
            Stats.sampleDimms();
            AppUsage.sample();
        }
    }

    Column {
        spacing: 2

        BarText {
            text: tip.title
        }

        Facts {
            parts: [tip.layout, tip.channels === 1 ? "single channel" : tip.channels === 2 ? "dual channel" : tip.channels === 4 ? "quad channel" : tip.channels > 0 ? `${tip.channels} channels` : ""].concat(Stats.dimmTemps.map(t => ({
                        text: Math.round(t),
                        widest: "00",
                        suffix: " °C",
                        color: Stats.tempColor(t, 75, 85)
                    })))
        }
    }

    // Used, cache, then free: the bar's figure is the used share.
    Column {
        spacing: 6

        Rectangle {
            width: 280
            height: 8
            radius: 2
            color: Theme.tint(0.1)

            Row {
                height: parent.height

                Rectangle {
                    width: parent.parent.width * Stats.memoryUsed / Math.max(1, Stats.memoryTotal)
                    height: parent.height
                    radius: 2
                    color: Stats.memory >= 90 ? Theme.red : Stats.memory >= 70 ? Theme.yellow : Theme.foregroundMuted
                }

                Rectangle {
                    width: parent.parent.width * Stats.memoryCache / Math.max(1, Stats.memoryTotal)
                    height: parent.height
                    color: Theme.foregroundFaint
                }
            }
        }

        Row {
            spacing: 16

            Repeater {
                model: [
                    {
                        label: "Used",
                        bytes: Stats.memoryUsed,
                        color: Theme.foregroundMuted
                    },
                    {
                        label: "Cache",
                        bytes: Stats.memoryCache,
                        color: Theme.foregroundFaint
                    },
                    {
                        label: "Free",
                        bytes: Stats.memoryFree,
                        color: Theme.tint(0.1)
                    }
                ]

                Row {
                    required property var modelData

                    spacing: 6

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 8
                        height: 8
                        radius: 2
                        color: parent.modelData.color
                    }

                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: parent.modelData.label
                        font.pixelSize: 14
                    }

                    Figure {
                        anchors.verticalCenter: parent.verticalCenter
                        widest: "00.0 GiB"
                        horizontalAlignment: Text.AlignRight
                        text: Stats.size(parent.modelData.bytes)
                        font.pixelSize: 14
                    }
                }
            }
        }
    }

    UsageRow {
        visible: Stats.swapTotal > 0
        label: "Swap"
        value: Stats.swapUsed / Math.max(1, Stats.swapTotal)
        amount: Stats.size(Stats.swapUsed)
        detail: `of ${Stats.size(Stats.swapTotal)}`
    }

    AppTable {
        widest: ["00.0 GiB"]
        rows: AppUsage.apps.slice().sort((a, b) => b.memory - a.memory).slice(0, 3).map(a => ({
                    name: a.name,
                    figures: [Stats.size(a.memory)]
                }))
    }
}
