import QtQuick

// The GPU tooltip: each GPU driving a screen in full, its load over five
// minutes, memory, video engine and busiest apps, then one line for each
// other GPU.
Column {
    id: tip

    // The first GPU counts as driving a screen should none report one.
    readonly property var full: Gpus.gpus.filter((g, i) => g.drives || i === 0)
    readonly property var idle: Gpus.gpus.filter((g, i) => !g.drives && i !== 0)

    // The edge temperature, and the hotspot where the GPU reports one.
    function temps(g) {
        return [g.temp, g.hotspot].map((t, i) => isNaN(t) ? "" : {
                    prefix: i === 0 ? "" : "hotspot ",
                    text: Math.round(t),
                    widest: "00",
                    suffix: " °C",
                    color: Stats.tempColor(t, i === 0 ? 80 : 95, i === 0 ? 90 : 105)
                });
    }

    spacing: 16

    Poll {
        onPoll: {
            Gpus.sample(false);
            Gpus.sampleClients();
        }
    }

    Repeater {
        model: tip.full

        Column {
            id: gpu

            required property var modelData
            readonly property var g: modelData

            spacing: 8

            Column {
                spacing: 2

                BarText {
                    text: gpu.g.name
                }

                Facts {
                    parts: [gpu.g.integrated ? "integrated" : ""]
                }
            }

            Row {
                spacing: 12

                Figure {
                    anchors.verticalCenter: parent.verticalCenter
                    widest: "100%"
                    text: `${isNaN(gpu.g.busy) ? 0 : gpu.g.busy}%`
                }

                Spark {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 120
                    height: 24
                    values: gpu.g.history
                    floor: 100
                }

                // An APU's power is the whole package's, which the cpu
                // tooltip shows.
                Facts {
                    anchors.verticalCenter: parent.verticalCenter
                    parts: [isNaN(gpu.g.clock) ? "" : {
                            text: Math.round(gpu.g.clock),
                            widest: "0000",
                            suffix: " MHz"
                        }].concat(tip.temps(gpu.g), [gpu.g.integrated || isNaN(gpu.g.power) ? "" : {
                                text: isNaN(gpu.g.powerCap) ? Math.round(gpu.g.power) : `${Math.round(gpu.g.power)} / ${Math.round(gpu.g.powerCap)}`,
                                widest: isNaN(gpu.g.powerCap) ? "000" : "000 / 000",
                                suffix: " W"
                            }, isNaN(gpu.g.fan) ? "" : {
                                prefix: "fan ",
                                text: Math.round(gpu.g.fan),
                                widest: gpu.g.fanUnit === "%" ? "100" : "0000",
                                suffix: gpu.g.fanUnit
                            }])
                }
            }

            // An APU's VRAM is a small carve-out of RAM that runs near full and
            // spills into shared memory, so it is not graded.
            UsageRow {
                visible: gpu.g.vramTotal > 0
                label: "VRAM"
                graded: !gpu.g.integrated
                value: gpu.g.vramUsed / gpu.g.vramTotal
                amount: Stats.size(gpu.g.vramUsed)
                detail: `of ${Stats.size(gpu.g.vramTotal)}`
            }

            UsageRow {
                visible: gpu.g.integrated && gpu.g.gttTotal > 0
                label: "Shared"
                value: gpu.g.gttUsed / gpu.g.gttTotal
                amount: Stats.size(gpu.g.gttUsed)
                detail: `of ${Stats.size(gpu.g.gttTotal)}`
            }

            Facts {
                parts: (!isNaN(gpu.g.decode) ? [["Video decode ", gpu.g.decode], ["encode ", gpu.g.encode]] : !isNaN(gpu.g.video) ? [["Video engine ", gpu.g.video]] : []).map(p => ({
                            prefix: p[0],
                            text: p[1],
                            widest: "100",
                            suffix: "%"
                        }))
            }

            // NVIDIA reports why it holds its clocks down, which takes a line
            // whether it does or not.
            Facts {
                parts: gpu.g.driver !== "nvidia" ? [] : [gpu.g.throttle.length > 0 ? {
                            text: `Clocks held down by ${gpu.g.throttle.join(" and ")}`,
                            color: Theme.yellow
                        } : "Clocks not held down"]
            }

            AppTable {
                widest: ["100%", "00.0 GiB"]
                rows: gpu.g.apps.filter(a => a.busy >= 0.1 || a.memory >= 1048576).sort((a, b) => b.busy - a.busy || b.memory - a.memory).slice(0, 3).map(a => ({
                            name: a.name,
                            figures: [Stats.percent(a.busy), Stats.size(a.memory)]
                        }))
            }
        }
    }

    Repeater {
        model: tip.idle

        Facts {
            required property var modelData

            parts: [modelData.name, {
                    text: isNaN(modelData.busy) ? 0 : modelData.busy,
                    widest: "100",
                    suffix: "%"
                }].concat(tip.temps(modelData))
        }
    }
}
