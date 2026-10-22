import QtQuick

// The apps using the most of something: a name, then a figure per column, each
// in a slot as wide as `widest` gives it. It holds `count` rows whatever it
// lists, so the tooltip keeps its height.
Column {
    id: table

    // [{name, figures: [string]}]
    property var rows: []
    // A figure's widest text per column.
    property var widest: []
    property int count: 3

    spacing: 4

    Caption {
        text: "Apps"
    }

    Repeater {
        model: table.count

        Row {
            id: app

            required property int index
            readonly property var entry: table.rows[index] ?? null

            height: 20
            spacing: 16

            BarText {
                anchors.verticalCenter: parent.verticalCenter
                width: 160
                elide: Text.ElideRight
                text: app.entry?.name ?? ""
                font.pixelSize: 14
            }

            Repeater {
                model: table.widest

                Figure {
                    required property string modelData
                    required property int index

                    anchors.verticalCenter: parent.verticalCenter
                    widest: modelData
                    horizontalAlignment: Text.AlignRight
                    text: app.entry?.figures[index] ?? ""
                    font.pixelSize: 14
                }
            }
        }
    }
}
