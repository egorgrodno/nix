import QtQuick
import QtQuick.Controls.Basic

// Sections of tasks under their titles, at least `minHeight` tall and scrolling
// past `maxHeight`, with one task's quick menu open at a time. A section
// without tasks is left out. A click on a task opens its card in place of the
// sections, as tall as they were or as the card needs, scrolling past
// `cardMaxHeight`; a card opened from it, for a subtask or the parent, goes
// over it, and Back leaves each in turn.
Flickable {
    id: list

    // [{ title, tasks, showDay, action: { label, run } }]
    required property var sections
    readonly property var shown: sections.filter(s => s.tasks.length > 0)
    property real minHeight: 0
    property real maxHeight: 360
    property real cardMaxHeight: 480
    property bool showProject: true
    property Item dragProxy: null
    // The id of the task whose menu is open.
    property string expanded: ""
    // The ids of the tasks whose cards are open, the last showing.
    property var trail: []
    // Where the sections were scrolled to as the first card opened.
    property real sectionsY: 0
    readonly property real sectionsHeight: Math.min(Math.max(column.height, minHeight), maxHeight)

    // The last card has closed.
    signal closed

    function open(id) {
        if (trail.length === 0)
            sectionsY = contentY;
        expanded = "";
        trail = [...trail, id];
        contentY = 0;
    }

    // To the card before, past those whose tasks have gone, or to the
    // sections.
    function back() {
        const rest = trail.slice(0, -1);
        while (rest.length > 0 && !Todoist.find(rest[rest.length - 1]))
            rest.pop();
        if (rest.length > 0) {
            trail = rest;
            contentY = 0;
        } else
            close();
    }

    function close() {
        if (trail.length === 0)
            return;
        trail = [];
        contentY = sectionsY;
        closed();
    }

    // For other sections, which start at the top rather than where the last
    // were scrolled to.
    function reset() {
        close();
        contentY = 0;
    }

    // The card goes first, so Undo brings the task back to the list.
    function remove(task) {
        back();
        Todoist.remove(task);
    }

    height: trail.length > 0 ? Math.max(sectionsHeight, Math.min(cards.height, cardMaxHeight)) : sectionsHeight
    contentHeight: trail.length > 0 ? cards.height : column.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    ScrollBar.vertical: OverlayScrollBar {}

    Column {
        id: column

        width: list.width
        visible: list.trail.length === 0

        Repeater {
            model: list.shown

            Column {
                id: section

                required property var modelData
                required property int index

                width: column.width

                // The title, and the section's action, if any, at its end.
                Item {
                    width: column.width
                    height: Math.max(title.implicitHeight, action.visible ? action.height + title.topPadding : 0)
                    visible: !!section.modelData.title

                    Caption {
                        id: title

                        anchors.bottom: parent.bottom
                        leftPadding: 8
                        topPadding: section.index > 0 ? 10 : 0
                        bottomPadding: 6
                        text: section.modelData.title ?? ""
                    }

                    TextButton {
                        id: action

                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        visible: !!section.modelData.action
                        text: section.modelData.action?.label ?? ""
                        onClicked: section.modelData.action.run()
                    }
                }

                Repeater {
                    model: section.modelData.tasks

                    TaskRow {
                        required property var modelData

                        width: column.width
                        task: modelData
                        showDay: section.modelData.showDay ?? false
                        showProject: list.showProject
                        dragProxy: list.dragProxy
                        expanded: list.expanded === modelData.id
                        onToggled: list.expanded = expanded ? "" : modelData.id
                        onOpened: list.open(modelData.id)
                    }
                }
            }
        }
    }

    // A new card for each task, so an edit never carries over to the next.
    Column {
        id: cards

        width: list.width

        Repeater {
            model: list.trail.slice(-1)

            TaskCard {
                required property string modelData

                width: cards.width
                taskId: modelData
                previous: list.trail[list.trail.length - 2] ?? ""
                onOpened: id => list.open(id)
                onClosed: list.back()
                onRemoveRequested: list.remove(task)
            }
        }
    }
}
