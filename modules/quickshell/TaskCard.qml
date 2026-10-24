import QtQuick
import QtQuick.Controls.Basic
import Quickshell

// A task in full: Back, its project and section, and buttons that open it in
// Todoist and delete it; its content and description, drawn from their
// Markdown and edited raw after a click; chips for its day and for its
// priority, each opening its choices under them, the day's led by a field
// Todoist reads a date or a recurrence out of, then its deadline and parent;
// then its subtasks, above a field that adds one, and its comments, with their
// attachments. A subtask, or the parent, asks for a card of its own. An edit
// saves on Enter, Ctrl Enter in the description, a press anywhere in the panel
// outside it, or the card closing; Escape drops it, and otherwise goes back.
Item {
    id: card

    required property string taskId
    // The card this one opened over, "" for none: the parent's link goes back
    // to it rather than open it again.
    property string previous: ""
    readonly property var found: Todoist.find(taskId)
    // Held from the start, so a task that leaves stays drawn until the list
    // closes its card.
    property var task: found
    readonly property string day: Todoist.dayOf(task)
    readonly property string time: Todoist.timeOf(task)
    readonly property var parentTask: task.parent_id ? Todoist.find(task.parent_id) : null
    readonly property var subtasks: Todoist.subtasks[taskId] ?? []
    readonly property var comments: Todoist.comments[taskId] ?? []
    // "content" or "description" while it is edited.
    property string editing: ""
    // "due" or "priority" while its chip's choices show.
    property string choosing: ""
    // The id of the subtask whose quick menu is open.
    property string expanded: ""
    // A field inside, left, gives the keyboard back here, where Escape goes
    // back.
    readonly property Item keyboardHome: card

    signal opened(string id)
    signal closed
    signal removeRequested

    function edit(key) {
        finish();
        const field = key === "content" ? titleField : descriptionField;
        field.text = task[key];
        editing = key;
        field.forceActiveFocus();
        field.cursorPosition = field.length;
    }

    // Saves the edit, if any, unless the task has gone, as one completed while
    // edited. Todoist refuses an empty content.
    function finish() {
        const key = editing;
        if (key === "")
            return;
        editing = "";
        const value = (key === "content" ? titleField : descriptionField).text.trim();
        if (found && (key === "description" || value !== ""))
            Todoist.edit(task, {
                [key]: value
            });
    }

    // The keyboard comes back for Escape, as the field it was in hides.
    function stop(save) {
        if (save)
            finish();
        else
            editing = "";
        forceActiveFocus();
    }

    // "" closes any. The keyboard comes back for Escape, as the field in the
    // day's choices may hold it.
    function choose(chip) {
        forceActiveFocus();
        choosing = choosing === chip ? "" : chip;
    }

    function openLink(link) {
        Launcher.run([Programs.xdgOpen, link]);
    }

    // "Today 14:02" from a UTC instant. Date reads no more than milliseconds,
    // and Todoist gives microseconds.
    function when(instant) {
        const date = new Date(instant.replace(/\.\d+/, ""));
        return `${Todoist.dayLabel(Dates.of(date))} ${Qt.locale("C").toString(date, "HH:mm")}`;
    }

    height: body.height
    Component.onCompleted: {
        task = found;
        forceActiveFocus();
    }
    Component.onDestruction: finish()
    onFoundChanged: {
        if (found)
            task = found;
        else
            closed();
    }
    Keys.onEscapePressed: closed()

    Connections {
        target: card.QsWindow.window
        enabled: card.editing !== ""

        function onPressed(position) {
            const field = card.editing === "content" ? titleField : descriptionField;
            if (!field.contains(field.mapFromItem(null, position)))
                card.stop(true);
        }
    }

    // A fill behind text that a click edits, on hover.
    component EditHint: Rectangle {
        required property MouseArea mouse

        radius: Theme.radius - 4
        color: mouse.containsMouse ? Theme.tint(0.07) : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }
    }

    // A chip's line: a caption as tall as the chips.
    component Fact: Caption {
        height: 28
        verticalAlignment: Text.AlignVCenter
    }

    Component {
        id: dueChoices

        Column {
            spacing: 8

            TextField {
                id: dueField

                readonly property string rule: card.task.due?.is_recurring ? card.task.due.string : ""

                width: parent.width
                height: 34
                leftPadding: 8
                rightPadding: 8
                topPadding: 0
                bottomPadding: 0
                verticalAlignment: TextInput.AlignVCenter
                placeholderText: "Type a date, as “fri 14:00” or “every 55 days”"
                placeholderTextColor: Theme.foregroundMuted
                color: Theme.foregroundStrong
                selectionColor: Theme.blue
                selectedTextColor: Theme.backgroundMain
                font.family: Theme.fontUI
                font.pixelSize: 14
                Component.onCompleted: {
                    text = rule;
                    selectAll();
                    forceActiveFocus();
                }
                // Sent again, an unchanged rule would move the task to its
                // first day from today.
                onAccepted: {
                    const text = dueField.text.trim();
                    if (text !== "" && text !== rule)
                        Todoist.schedule(card.task, text);
                    card.choose("");
                }
                Keys.onEscapePressed: card.choose("")

                background: Rectangle {
                    radius: Theme.radius - 4
                    color: Theme.tint(0.06)
                    border.width: 1
                    border.color: dueField.activeFocus ? Theme.blue : Theme.tint(0.12)
                }
            }

            DateButtons {
                width: parent.width
                task: card.task
                foldable: false
                onPicked: day => {
                    Todoist.reschedule(card.task, day);
                    card.choose("");
                }
            }
        }
    }

    Component {
        id: priorityChoices

        Flow {
            spacing: 6

            Repeater {
                model: [4, 3, 2, 1]

                TextButton {
                    required property int modelData

                    text: `\u{F023B} P${5 - modelData}`
                    textColor: Todoist.priorityColor(modelData)
                    lit: card.task.priority === modelData
                    onClicked: {
                        Todoist.edit(card.task, {
                            priority: modelData
                        });
                        card.choose("");
                    }
                }
            }
        }
    }

    Column {
        id: body

        width: parent.width
        spacing: 10

        Item {
            width: parent.width
            height: 28

            Chevron {
                by: -1
                onStepped: card.closed()
            }

            Caption {
                x: 32
                width: todoistButton.x - x - 8
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: [Todoist.projectName(card.task), Todoist.sections[card.task.section_id]?.name ?? ""].filter(s => s).join(" › ")
            }

            TextButton {
                id: todoistButton

                anchors.right: deleteButton.left
                anchors.rightMargin: 6
                text: "\u{F03CC}"
                onClicked: card.openLink(`https://app.todoist.com/app/task/${card.task.id}`)
            }

            TextButton {
                id: deleteButton

                anchors.right: parent.right
                text: "\u{F0A7A}"
                hoverFill: Theme.alpha(Theme.red, 0.5)
                onClicked: card.removeRequested()
            }
        }
        Item {
            width: parent.width
            height: card.editing === "content" ? titleField.height : Math.max(34, title.height + 12)

            TaskRing {
                x: 8
                y: 8
                task: card.task
            }

            EditHint {
                x: 28
                width: parent.width - x
                height: parent.height
                visible: !titleField.visible
                mouse: titleMouse
            }

            MouseArea {
                id: titleMouse

                x: 28
                width: parent.width - x
                height: parent.height
                visible: !titleField.visible
                hoverEnabled: true
                onClicked: card.edit("content")
            }

            Markdown {
                id: title

                x: 36
                y: 6
                width: parent.width - x - 8
                visible: !titleField.visible
                markdown: card.task.content
            }

            TextField {
                id: titleField

                x: 28
                width: parent.width - x
                height: 34
                visible: card.editing === "content"
                leftPadding: 8
                rightPadding: 8
                topPadding: 0
                bottomPadding: 0
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.foregroundStrong
                selectionColor: Theme.blue
                selectedTextColor: Theme.backgroundMain
                font.family: Theme.fontUI
                font.pixelSize: 16
                onAccepted: card.stop(true)
                Keys.onEscapePressed: card.stop(false)

                background: Rectangle {
                    radius: Theme.radius - 4
                    color: Theme.tint(0.06)
                    border.width: 1
                    border.color: Theme.blue
                }
            }
        }

        Column {
            x: 36
            width: parent.width - 44
            spacing: 10

            Item {
                width: parent.width
                height: description.height
                visible: !descriptionField.visible

                EditHint {
                    anchors.fill: parent
                    anchors.margins: -4
                    anchors.leftMargin: -8
                    mouse: descriptionMouse
                }

                MouseArea {
                    id: descriptionMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: card.edit("description")
                }

                Markdown {
                    id: description

                    width: parent.width
                    markdown: card.task.description || "Add a description"
                    color: card.task.description ? Theme.foregroundMain : Theme.foregroundMuted
                    font.pixelSize: 14
                }
            }

            Column {
                x: -8
                width: parent.width + 8
                visible: card.editing === "description"
                spacing: 4

                TextArea {
                    id: descriptionField

                    width: parent.width
                    padding: 8
                    wrapMode: TextEdit.Wrap
                    placeholderText: "Markdown"
                    placeholderTextColor: Theme.foregroundMuted
                    color: Theme.foregroundStrong
                    selectionColor: Theme.blue
                    selectedTextColor: Theme.backgroundMain
                    font.family: Theme.fontUI
                    font.pixelSize: 14
                    Keys.onPressed: event => {
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && event.modifiers & Qt.ControlModifier) {
                            card.stop(true);
                            event.accepted = true;
                        }
                    }
                    Keys.onEscapePressed: card.stop(false)

                    background: Rectangle {
                        radius: Theme.radius - 4
                        color: Theme.tint(0.06)
                        border.width: 1
                        border.color: Theme.blue
                    }
                }

                Caption {
                    leftPadding: 8
                    text: "Ctrl Enter saves · Escape cancels"
                    font.pixelSize: 12
                }
            }

            Flow {
                width: parent.width
                spacing: 6

                TextButton {
                    text: {
                        const day = card.day ? [Todoist.dayLabel(card.day), card.time].filter(s => s).join(" ") : "No date";
                        return card.task.due?.is_recurring ? `\u{F00EE} ${day}  \u{F0456} ${card.task.due.string}` : `\u{F00EE} ${day}`;
                    }
                    textColor: Todoist.late(card.task) ? Theme.red : card.day ? Theme.foregroundStrong : Theme.foregroundMuted
                    lit: card.choosing === "due"
                    onClicked: card.choose("due")
                }

                TextButton {
                    text: `\u{F023B} P${5 - card.task.priority}`
                    textColor: Todoist.priorityColor(card.task.priority)
                    lit: card.choosing === "priority"
                    onClicked: card.choose("priority")
                }

                Fact {
                    visible: !!card.task.deadline
                    leftPadding: 6
                    text: `Deadline ${card.task.deadline ? Todoist.dayLabel(card.task.deadline.date) : ""}`
                }

                Fact {
                    visible: card.parentTask !== null
                    width: Math.min(implicitWidth, parent.width)
                    leftPadding: 6
                    elide: Text.ElideRight
                    text: `Subtask of ${card.parentTask?.content ?? ""}`
                    color: parentHover.hovered ? Theme.foregroundStrong : Theme.foregroundMuted

                    HoverHandler {
                        id: parentHover
                    }

                    TapHandler {
                        onTapped: card.parentTask.id === card.previous ? card.closed() : card.opened(card.parentTask.id)
                    }
                }
            }

            Loader {
                width: parent.width
                active: card.choosing !== ""
                visible: active
                sourceComponent: card.choosing === "priority" ? priorityChoices : dueChoices
            }
        }

        Column {
            x: 28
            width: parent.width - x

            Caption {
                visible: card.subtasks.length > 0
                leftPadding: 8
                bottomPadding: 6
                text: "Subtasks"
            }

            Repeater {
                model: card.subtasks

                TaskRow {
                    required property var modelData

                    width: parent.width
                    task: modelData
                    showDay: true
                    showProject: false
                    expanded: card.expanded === modelData.id
                    onToggled: card.expanded = expanded ? "" : modelData.id
                    onOpened: card.opened(modelData.id)
                }
            }

            TaskField {
                width: parent.width
                parentId: card.taskId
                Keys.onEscapePressed: {
                    text = "";
                    card.forceActiveFocus();
                }
            }
        }

        Column {
            x: 36
            width: parent.width - 44
            visible: card.comments.length > 0
            spacing: 10

            Caption {
                text: "Comments"
            }

            Repeater {
                model: card.comments

                Column {
                    id: comment

                    required property var modelData
                    readonly property var attachment: modelData.file_attachment ?? null

                    width: parent.width
                    spacing: 4

                    Caption {
                        text: [comment.modelData.posted_uid === Todoist.userId ? "" : Todoist.collaborators[comment.modelData.posted_uid]?.full_name ?? "", card.when(comment.modelData.posted_at)].filter(s => s).join(" · ")
                        font.pixelSize: 12
                    }

                    Markdown {
                        width: parent.width
                        visible: markdown !== ""
                        markdown: comment.modelData.content
                        color: Theme.foregroundMain
                        font.pixelSize: 14
                    }

                    TextButton {
                        visible: comment.attachment !== null
                        text: `\u{F03E2} ${comment.attachment?.file_name ?? comment.attachment?.title ?? ""}`
                        onClicked: card.openLink(comment.attachment.file_url ?? comment.attachment.url)
                    }
                }
            }
        }
    }
}
