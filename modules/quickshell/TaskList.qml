import QtQuick

// Sections of tasks under their titles, at least `minHeight` tall and scrolling
// past `maxHeight`, with one task's quick menu open at a time. A section
// without tasks is left out.
Flickable {
    id: list

    // [{ title, tasks, showDay, action: { label, run } }]
    required property var sections
    readonly property var shown: sections.filter(s => s.tasks.length > 0)
    property real minHeight: 0
    property real maxHeight: 360
    property bool showProject: true
    property Item dragProxy: null
    // The id of the task whose menu is open.
    property string expanded: ""

    height: Math.min(Math.max(contentHeight, minHeight), maxHeight)
    contentHeight: column.height
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    interactive: contentHeight > height

    Column {
        id: column

        width: list.width

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
                    }
                }
            }
        }
    }
}
