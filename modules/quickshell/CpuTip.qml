import QtQuick

// The cpu tooltip: the model, the total with five minutes of it, the clock,
// temperature and package power, the load, each core, and the busiest apps.
Column {
    id: tip

    // An APU's GPU reports the whole package's power.
    readonly property real packagePower: Gpus.gpus.find(g => g.integrated && !isNaN(g.power))?.power ?? NaN

    function duration(seconds) {
        const days = Math.floor(seconds / 86400), hours = Math.floor(seconds % 86400 / 3600), minutes = Math.floor(seconds % 3600 / 60);
        return days > 0 ? `${days} d ${hours} h` : hours > 0 ? `${hours} h ${minutes} min` : `${minutes} min`;
    }

    spacing: 12

    Poll {
        onPoll: {
            Stats.sampleCpu();
            Stats.sampleCpuDetails();
            Gpus.sample(false);
            AppUsage.sample();
        }
    }

    Column {
        spacing: 2

        BarText {
            text: Stats.cpuModel
        }

        Facts {
            parts: [`${Stats.physicalCores.length} cores`, `${Stats.cores.length} threads`, isNaN(Stats.maxClock) ? "" : `up to ${(Stats.maxClock / 1000).toFixed(1)} GHz`]
        }
    }

    Row {
        spacing: 12

        Figure {
            anchors.verticalCenter: parent.verticalCenter
            widest: "100%"
            text: `${Stats.cpu}%`
        }

        Spark {
            anchors.verticalCenter: parent.verticalCenter
            width: 120
            height: 24
            values: Stats.cpuHistory
            floor: 100
        }

        Facts {
            anchors.verticalCenter: parent.verticalCenter
            parts: [Stats.clocks.length > 0 ? {
                    text: (Stats.clocks.reduce((a, b) => a + b, 0) / Stats.clocks.length / 1000).toFixed(1),
                    widest: "0.0",
                    suffix: " GHz"
                } : "", isNaN(Stats.cpuTemp) ? "" : {
                    text: Math.round(Stats.cpuTemp),
                    widest: "00",
                    suffix: " °C",
                    color: Stats.tempColor(Stats.cpuTemp, 80, 90)
                }, isNaN(tip.packagePower) ? "" : {
                    text: tip.packagePower < 100 ? tip.packagePower.toFixed(1) : Math.round(tip.packagePower),
                    widest: "00.0",
                    suffix: " W"
                }]
        }
    }

    Facts {
        // Four characters a load, two decimals below 10 and one above.
        parts: Stats.load.map((l, i) => ({
                    prefix: i === 0 ? "Load 1/5/15 min " : "",
                    separator: " ",
                    text: l.toFixed(l < 10 ? 2 : 1),
                    widest: "0.00"
                })).concat([Stats.uptime > 0 ? {
                        prefix: "up ",
                        text: tip.duration(Stats.uptime),
                        widest: "00 h 00 min"
                    } : ""])
    }

    CoreChart {}

    AppTable {
        widest: ["100%"]
        rows: AppUsage.apps.filter(a => a.cpu >= 0.1).sort((a, b) => b.cpu - a.cpu).slice(0, 3).map(a => ({
                    name: a.name,
                    figures: [Stats.percent(a.cpu)]
                }))
    }
}
