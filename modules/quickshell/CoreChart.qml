import QtQuick

// A row per physical core: a meter and figure per thread, then the clock its
// threads share, the higher of their readings, in two columns past twelve
// cores, each under a header.
Row {
    id: chart

    readonly property int columns: Stats.physicalCores.length > 12 ? 2 : 1
    readonly property int perColumn: Math.ceil(Stats.physicalCores.length / columns)
    readonly property int threads: Stats.physicalCores[0]?.length ?? 1
    readonly property int meterWidth: 56
    readonly property int threadGap: 32

    spacing: 48

    TextMetrics {
        id: indexSlot

        font.family: Theme.fontMono
        font.pixelSize: 14
        font.hintingPreference: Font.PreferFullHinting
        text: "00"
    }

    TextMetrics {
        id: usageSlot

        font.family: Theme.fontMono
        font.pixelSize: 14
        font.hintingPreference: Font.PreferFullHinting
        text: "100%"
    }

    TextMetrics {
        id: clockSlot

        font.family: Theme.fontMono
        font.pixelSize: 14
        font.hintingPreference: Font.PreferFullHinting
        text: "0.0 GHz"
    }

    Repeater {
        model: chart.columns

        Column {
            id: column

            required property int index

            spacing: 4

            Row {
                spacing: 8

                Item {
                    width: indexSlot.advanceWidth
                    height: 1
                }

                Row {
                    spacing: chart.threadGap

                    Caption {
                        width: chart.threads * (chart.meterWidth + 8 + usageSlot.advanceWidth) + (chart.threads - 1) * chart.threadGap
                        text: chart.threads > 1 ? "threads" : "load"
                    }

                    Caption {
                        width: clockSlot.advanceWidth
                        horizontalAlignment: Text.AlignHCenter
                        text: "clock"
                    }
                }
            }

            Repeater {
                model: Stats.physicalCores.slice(column.index * chart.perColumn, (column.index + 1) * chart.perColumn)

                Row {
                    id: core

                    // Its threads, as indices into Stats.cores.
                    required property var modelData
                    required property int index

                    spacing: 8

                    Figure {
                        anchors.verticalCenter: parent.verticalCenter
                        widest: "00"
                        horizontalAlignment: Text.AlignRight
                        text: column.index * chart.perColumn + core.index
                        color: Theme.foregroundMuted
                        font.pixelSize: 14
                    }

                    Row {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: chart.threadGap

                        Repeater {
                            model: core.modelData

                            Row {
                                required property int modelData
                                readonly property int usage: Stats.cores[modelData] ?? 0

                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 8

                                Meter {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: chart.meterWidth
                                    value: parent.usage / 100
                                }

                                Figure {
                                    anchors.verticalCenter: parent.verticalCenter
                                    widest: "100%"
                                    horizontalAlignment: Text.AlignRight
                                    text: `${parent.usage}%`
                                    font.pixelSize: 14
                                }
                            }
                        }

                        Figure {
                            anchors.verticalCenter: parent.verticalCenter
                            widest: "0.0 GHz"
                            horizontalAlignment: Text.AlignRight
                            text: `${(Math.max(...core.modelData.map(t => Stats.clocks[t] ?? 0)) / 1000).toFixed(1)} GHz`
                            color: Theme.foregroundMuted
                            font.pixelSize: 14
                        }
                    }
                }
            }
        }
    }
}
