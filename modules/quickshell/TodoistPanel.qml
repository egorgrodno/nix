import QtQuick

// Over the tasks module: Today, under what is overdue, Upcoming, by day, and
// the Inbox, below a Quick Add field, whose task takes today as its date from
// Today. Tab and Shift Tab change the view. It syncs as it opens.
Panel {
    id: panel

    property string view: "today"
    readonly property var views: [
        {
            id: "today",
            label: "Today",
            empty: "Nothing due today"
        },
        {
            id: "upcoming",
            label: "Upcoming",
            empty: "Nothing scheduled"
        },
        {
            id: "inbox",
            label: "Inbox",
            empty: "The Inbox is empty"
        }
    ]
    readonly property var sections: {
        const today = Todoist.today;
        switch (view) {
        case "upcoming":
            return Object.keys(Todoist.byDay).filter(d => d > today).sort().map(d => ({
                        title: Todoist.dayLabel(d),
                        tasks: Todoist.byDay[d]
                    }));
        case "inbox":
            return [
                {
                    tasks: Todoist.tasks.filter(t => t.project_id === Todoist.inbox),
                    showDay: true
                }
            ];
        }
        return [
            {
                title: "Overdue",
                tasks: Todoist.overdue,
                showDay: true,
                action: Todoist.moveOverdue
            },
            {
                title: Todoist.overdue.length > 0 ? "Today" : "",
                tasks: Todoist.byDay[today] ?? []
            }
        ];
    }

    function cycle(step) {
        const index = views.findIndex(v => v.id === view);
        view = views[(index + step + views.length) % views.length].id;
    }

    boxWidth: 440
    onViewChanged: list.close()
    Component.onCompleted: {
        Todoist.sync();
        field.forceActiveFocus();
    }

    Column {
        width: panel.contentWidth
        spacing: 12

        Row {
            spacing: 6

            Repeater {
                model: panel.views

                TextButton {
                    required property var modelData

                    text: modelData.label
                    lit: panel.view === modelData.id
                    onClicked: panel.view = modelData.id
                }
            }
        }

        TaskField {
            id: field

            width: parent.width
            day: panel.view === "today" ? Todoist.today : ""
            Keys.onPressed: event => {
                if (event.key === Qt.Key_Tab || event.key === Qt.Key_Backtab) {
                    panel.cycle(event.key === Qt.Key_Tab ? 1 : -1);
                    event.accepted = true;
                }
            }
        }

        TaskList {
            id: list

            width: parent.width
            maxHeight: 10 * 36
            sections: panel.sections
            onClosed: field.forceActiveFocus()
        }

        Caption {
            visible: list.shown.length === 0 && list.trail.length === 0
            leftPadding: 8
            text: panel.views.find(v => v.id === panel.view).empty
        }

        TodoistStatus {}
    }
}
