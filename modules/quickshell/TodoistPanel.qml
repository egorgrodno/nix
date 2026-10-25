import QtQuick

// Over the tasks module: Today, under what is overdue, Upcoming, by day, the
// Inbox, and Projects, one project at a time by section, below a Quick Add
// field, whose task takes today as its date from Today and the project from
// Projects. Tab and Shift Tab change the view. It syncs as it opens, on the
// view, project and cards the last was left on.
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
        },
        {
            id: "projects",
            label: "Projects",
            empty: "Nothing in this project"
        }
    ]
    readonly property var projects: Object.values(Todoist.projects).filter(p => p.id !== Todoist.inbox).sort((a, b) => a.child_order - b.child_order)
    // The one Projects shows.
    property string project: projects[0]?.id ?? ""
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
        case "projects": {
            // In Todoist's order, a subtask only in its parent's card,
            // unless the lists leave the parent out.
            const tasks = Todoist.tasks.filter(t => t.project_id === project);
            const ids = new Set(tasks.map(t => t.id));
            const top = tasks.filter(t => !ids.has(t.parent_id)).sort((a, b) => a.child_order - b.child_order);
            const projectSections = Object.values(Todoist.sections).filter(s => s.project_id === project).sort((a, b) => a.section_order - b.section_order);
            return [
                {
                    tasks: top.filter(t => !Todoist.sections[t.section_id]),
                    showDay: true
                },
                ...projectSections.map(s => ({
                            title: s.name,
                            tasks: top.filter(t => t.section_id === s.id),
                            showDay: true
                        }))
            ];
        }
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
    onViewChanged: list.reset()
    onProjectChanged: list.reset()
    // The view and project go first, as changing either closes the cards. Set
    // once rather than bound, as a binding would rebuild the card on every
    // sync. A project or task gone since is left out, Projects then giving way
    // to Today.
    Component.onCompleted: {
        const place = Todoist.place;
        const kept = projects.some(p => p.id === place.project);
        if (kept)
            project = place.project;
        view = place.view === "projects" && !kept ? "today" : place.view;
        list.trail = place.trail.filter(id => Todoist.find(id));
        Todoist.sync();
        if (list.trail.length === 0)
            field.forceActiveFocus();
    }
    Component.onDestruction: Todoist.place = {
        view: view,
        project: project,
        trail: list.trail
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

        Flow {
            width: parent.width
            visible: panel.view === "projects"
            spacing: 6

            Repeater {
                model: panel.projects

                TextButton {
                    required property var modelData

                    text: modelData.name
                    lit: panel.project === modelData.id
                    onClicked: panel.project = modelData.id
                }
            }
        }

        TaskField {
            id: field

            width: parent.width
            day: panel.view === "today" ? Todoist.today : ""
            project: panel.view === "projects" ? panel.project : ""
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
            showProject: panel.view !== "projects"
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
