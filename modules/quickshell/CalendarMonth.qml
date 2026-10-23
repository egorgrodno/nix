import QtQuick

// A month's days in six weeks under the weekdays' names, from the first weekday
// Nix sets: the days of the months either side faint, today in blue and the
// selected day lit, each with a dot while Todoist has tasks due on it. A day
// takes a task dropped on it.
Grid {
    id: calendar

    // Months since the start of year 0, as the calendar panel pages them.
    required property int month
    // ISO dates.
    required property string today
    required property string selected
    required property int cellWidth
    required property int cellHeight
    // Days shown before the 1st.
    readonly property int lead: (Dates.weekday(Dates.day(month, 1)) - Host.firstDayOfWeek + 7) % 7
    readonly property var days: Array.from({
        length: 42
    }, (_, i) => Dates.day(month, i - lead + 1))

    signal picked(string day)

    columns: 7
    columnSpacing: 2
    rowSpacing: 2

    Repeater {
        model: 7

        BarText {
            required property int index

            width: calendar.cellWidth
            height: calendar.cellHeight
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: Qt.locale().dayName((Host.firstDayOfWeek + index) % 7, Locale.ShortFormat).slice(0, 2)
            color: Theme.foregroundMuted
            font.pixelSize: 13
        }
    }

    // New cells for each month: the pager hands a grid another month as the
    // view crosses into the next, and a kept cell would fade from the colour
    // of the day it showed before, as today's blue.
    Repeater {
        model: calendar.days

        Rectangle {
            id: cell

            required property string modelData
            readonly property string day: modelData
            readonly property bool inMonth: Dates.month(day) === calendar.month
            readonly property bool isToday: inMonth && day === calendar.today
            readonly property int taskCount: Todoist.byDay[day]?.length ?? 0

            width: calendar.cellWidth
            height: calendar.cellHeight
            radius: 4
            color: isToday ? Theme.blue : drop.containsDrag ? Theme.alpha(Theme.blue, 0.35) : inMonth && day === calendar.selected ? Theme.tint(0.12) : mouse.containsMouse ? Theme.tint(0.07) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }

            // Lifted while Todoist is on, clear of the dot.
            BarText {
                anchors.centerIn: parent
                anchors.verticalCenterOffset: Todoist.enabled ? -2 : 0
                text: Number(cell.day.slice(8))
                color: cell.isToday ? Theme.backgroundMain : cell.inMonth ? Theme.foregroundStrong : Theme.foregroundFaint
                font.family: Theme.fontMono
                font.pixelSize: 15
            }

            // Todoist's tasks due that day: red once past.
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 2
                width: 4
                height: 4
                radius: 2
                visible: cell.taskCount > 0
                color: cell.isToday ? Theme.backgroundMain : cell.day < calendar.today ? Theme.red : cell.inMonth ? Theme.foregroundMuted : Theme.foregroundFaint
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                onClicked: calendar.picked(cell.day)
            }

            // Takes a task dragged from a task list, which reads `day`.
            DropArea {
                id: drop

                readonly property string day: cell.day

                anchors.fill: parent
                keys: ["task"]
            }
        }
    }
}
