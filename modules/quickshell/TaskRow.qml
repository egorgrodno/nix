import QtQuick

// A task: a ring in its priority's colour that completes it, its content, a
// mark if it recurs, its project unless `showProject` is off, and its time, or
// its day where `showDay`, in red once past. A click opens its quick menu below
// it: Today, Tomorrow, Next week, No date, a month to pick a day from, and
// Delete. With a `dragProxy`, a drag carries it onto a day of the calendar.
Column {
    id: row

    required property var task
    property bool expanded: false
    property bool showDay: false
    property bool showProject: true
    // An item with `task`, `dragging` and `grab` properties and the day under
    // it as `target`, which the calendar's days take drops from.
    property Item dragProxy: null
    property bool picking: false
    readonly property string day: Todoist.dayOf(task)
    readonly property string time: Todoist.timeOf(task)
    readonly property color priorityColor: [Theme.foregroundMuted, Theme.foregroundMuted, Theme.blue, Theme.yellow, Theme.red][task.priority] ?? Theme.foregroundMuted

    signal toggled

    function reschedule(day) {
        toggled();
        Todoist.reschedule(task, day);
    }

    onExpandedChanged: if (!expanded)
        picking = false

    Item {
        id: line

        width: row.width
        height: 36

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius - 4
            color: row.expanded || mouse.containsMouse ? Theme.tint(0.07) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            drag.target: row.dragProxy
            drag.threshold: 8
            preventStealing: row.dragProxy !== null
            drag.onActiveChanged: if (row.dragProxy)
                row.dragProxy.dragging = drag.active
            onPressed: event => {
                const proxy = row.dragProxy;
                if (!proxy)
                    return;
                const at = line.mapToItem(proxy.parent, 0, 0);
                proxy.x = at.x;
                proxy.y = at.y;
                proxy.width = line.width;
                proxy.grab = Qt.point(event.x, event.y);
                proxy.task = row.task;
            }
            // The proxy hides first and the task moves after the release: the
            // move takes this row out of its list, and a row destroyed here
            // would never report the drag's end.
            onReleased: {
                const proxy = row.dragProxy;
                if (!proxy?.dragging)
                    return;
                const target = proxy.target;
                const task = row.task;
                proxy.dragging = false;
                if (target)
                    Qt.callLater(() => Todoist.reschedule(task, target.day));
            }
            onClicked: row.toggled()
        }

        Rectangle {
            id: ring

            x: 8
            anchors.verticalCenter: parent.verticalCenter
            width: 18
            height: 18
            radius: 9
            color: ringMouse.containsMouse ? Theme.alpha(row.priorityColor, 0.25) : "transparent"
            border.width: 2
            border.color: row.priorityColor

            BarText {
                anchors.centerIn: parent
                visible: ringMouse.containsMouse
                text: "\u{F012C}"
                color: row.priorityColor
                font.pixelSize: 13
            }

            MouseArea {
                id: ringMouse

                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                onClicked: Todoist.complete(row.task)
            }
        }

        BarText {
            x: 36
            width: meta.x - x - 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: row.task.content
            font.pixelSize: 14
        }

        Row {
            id: meta

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Caption {
                visible: row.task.due?.is_recurring ?? false
                text: "\u{F0456}"
            }

            // Capped, so a long name leaves the content room.
            Caption {
                visible: row.showProject
                width: Math.min(implicitWidth, row.width / 4)
                elide: Text.ElideRight
                text: Todoist.projectName(row.task)
            }

            Caption {
                visible: text !== ""
                text: [row.showDay && row.day ? Todoist.dayLabel(row.day) : "", row.time].filter(s => s).join(" ")
                color: Todoist.late(row.task) ? Theme.red : Theme.foregroundMuted
            }
        }
    }

    Column {
        x: 36
        width: row.width - 36 - 8
        visible: row.expanded
        topPadding: 4
        bottomPadding: 10
        spacing: 8

        Flow {
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
                    visible: modelData.day !== row.day
                    onClicked: row.reschedule(modelData.day)
                }
            }

            TextButton {
                text: "Pick a day"
                lit: row.picking
                onClicked: row.picking = !row.picking
            }

            // The menu closes first, so Undo brings the task back closed.
            TextButton {
                text: "Delete"
                hoverFill: Theme.alpha(Theme.red, 0.5)
                onClicked: {
                    row.toggled();
                    Todoist.remove(row.task);
                }
            }
        }

        Loader {
            active: row.picking
            visible: active

            sourceComponent: DayPicker {
                selected: row.day
                onPicked: day => row.reschedule(day)
            }
        }
    }
}
