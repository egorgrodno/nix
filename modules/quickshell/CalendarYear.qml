import QtQuick

// A year's months, four to a row: the current one in blue, as today is in the
// days, and the one the days showed lit.
Grid {
    id: grid

    required property int year
    // Months since the start of year 0.
    required property int current
    required property int shown

    signal picked(int month)

    columns: 4
    spacing: 4

    Repeater {
        model: 12

        Rectangle {
            id: tile

            required property int index
            readonly property int month: grid.year * 12 + index
            readonly property bool isCurrent: month === grid.current

            width: (grid.width - 3 * grid.spacing) / 4
            height: (grid.height - 2 * grid.spacing) / 3
            radius: Theme.radius - 4
            color: isCurrent ? Theme.blue : month === grid.shown ? Theme.tint(0.12) : mouse.containsMouse ? Theme.tint(0.07) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }

            BarText {
                anchors.centerIn: parent
                text: Qt.locale().standaloneMonthName(tile.index, Locale.ShortFormat)
                color: tile.isCurrent ? Theme.backgroundMain : Theme.foregroundStrong
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                onClicked: grid.picked(tile.month)
            }
        }
    }
}
