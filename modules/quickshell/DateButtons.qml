import QtQuick

// The days a task moves to in a click, each but the one it has: Today,
// Tomorrow, the next start of a week and No date, then Pick a day, which opens
// a month under them, or the month always unless `foldable`. Buttons given as
// children follow.
Column {
    id: buttons

    required property var task
    property bool foldable: true
    property bool picking: false
    default property alias extra: flow.data
    readonly property string day: Todoist.dayOf(task)

    signal picked(string day)

    spacing: 8

    Flow {
        id: flow

        width: parent.width
        spacing: 6

        Repeater {
            model: {
                const today = Todoist.today;
                // The next start of a week, a week away from one.
                const ahead = (Host.firstDayOfWeek - Dates.weekday(today) + 7) % 7 || 7;
                return [
                    {
                        label: "Today",
                        day: today
                    },
                    {
                        label: "Tomorrow",
                        day: Dates.add(today, 1)
                    },
                    {
                        label: "Next week",
                        day: Dates.add(today, ahead)
                    },
                    {
                        label: "No date",
                        day: ""
                    }
                ];
            }

            TextButton {
                required property var modelData

                text: modelData.label
                visible: modelData.day !== buttons.day
                onClicked: buttons.picked(modelData.day)
            }
        }

        TextButton {
            visible: buttons.foldable
            text: "Pick a day"
            lit: buttons.picking
            onClicked: buttons.picking = !buttons.picking
        }
    }

    Loader {
        active: buttons.picking || !buttons.foldable
        visible: active

        sourceComponent: DayPicker {
            selected: buttons.day
            onPicked: day => buttons.picked(day)
        }
    }
}
