import QtQuick

// A ring in a task's priority's colour, a check in it on hover, that completes
// the task.
Rectangle {
    id: ring

    required property var task
    readonly property color priorityColor: Todoist.priorityColor(task.priority)

    width: 18
    height: 18
    radius: 9
    color: mouse.containsMouse ? Theme.alpha(priorityColor, 0.25) : "transparent"
    border.width: 2
    border.color: priorityColor

    BarText {
        anchors.centerIn: parent
        visible: mouse.containsMouse
        text: "\u{F012C}"
        color: ring.priorityColor
        font.pixelSize: 13
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        anchors.margins: -4
        hoverEnabled: true
        onClicked: Todoist.complete(ring.task)
    }
}
