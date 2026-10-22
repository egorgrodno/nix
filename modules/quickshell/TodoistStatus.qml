import QtQuick

// Under the tasks: the last change, with Undo while it lasts, else what went
// wrong with Todoist.
Item {
    width: parent?.width ?? 0
    height: 28
    visible: Todoist.lastChange !== null || Todoist.error !== ""

    Caption {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - (undo.visible ? undo.width + 12 : 0)
        leftPadding: 8
        elide: Text.ElideRight
        text: Todoist.lastChange?.text ?? Todoist.error
        color: Todoist.lastChange ? Theme.foregroundMuted : Theme.yellow
    }

    TextButton {
        id: undo

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: Todoist.lastChange !== null
        text: "Undo"
        onClicked: Todoist.undo()
    }
}
