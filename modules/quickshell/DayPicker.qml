import QtQuick

// A month to pick a day from, under its name between chevrons that step it,
// sliding as the calendar's does. It opens on the month of `selected`, else
// today's.
Column {
    id: picker

    // An ISO date, or "" for none.
    required property string selected
    property int cellWidth: 32
    property int cellHeight: 24

    signal picked(string day)

    spacing: 4
    Component.onCompleted: months.go(Dates.month(selected || Todoist.today), false)

    Pager {
        id: months
    }

    Item {
        width: pages.width
        height: 28

        Chevron {
            by: -1
            onStepped: by => months.go(months.page + by)
        }

        BarText {
            anchors.centerIn: parent
            text: `${Qt.locale().standaloneMonthName(months.page % 12)} ${Math.floor(months.page / 12)}`
            font.pixelSize: 14
        }

        Chevron {
            anchors.right: parent.right
            by: 1
            onStepped: by => months.go(months.page + by)
        }
    }

    Item {
        id: pages

        width: 7 * picker.cellWidth + 6 * 2
        height: 7 * picker.cellHeight + 6 * 2
        clip: true

        Repeater {
            model: 2

            CalendarMonth {
                required property int index

                month: Math.floor(months.position) + index
                today: Todoist.today
                selected: picker.selected
                cellWidth: picker.cellWidth
                cellHeight: picker.cellHeight
                x: (month - months.position) * pages.width
                onPicked: day => picker.picked(day)
            }
        }
    }
}
