import QtQuick

// The cpu tooltip: the total, then a meter per core, in two columns past 16.
Column {
    spacing: 8

    BarText {
        text: `Total ${Stats.cpu}%`
    }

    Grid {
        columns: Stats.cores.length > 16 ? 2 : 1
        columnSpacing: 24
        rowSpacing: 4
        flow: Grid.TopToBottom
        rows: Math.ceil(Stats.cores.length / columns)

        Repeater {
            model: Stats.cores

            Row {
                required property int modelData
                required property int index

                spacing: 8

                Figure {
                    widest: "00"
                    horizontalAlignment: Text.AlignRight
                    text: parent.index
                    color: Theme.foregroundMuted
                    font.pixelSize: 14
                }

                Meter {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 120
                    value: parent.modelData / 100
                }

                Figure {
                    widest: "100%"
                    horizontalAlignment: Text.AlignRight
                    text: `${parent.modelData}%`
                    font.pixelSize: 14
                }
            }
        }
    }
}
