import QtQuick

// A battery drawn filled to its charge, with a tick where the charge limit
// stops charging.
Item {
    id: gauge

    property real value
    property color fill: Theme.foregroundMain
    // From 0 to 1; at 1 there is no tick.
    property real limit: 1

    width: 26
    height: 13

    Rectangle {
        id: body

        width: parent.width - 3
        height: parent.height
        radius: 3
        color: "transparent"
        border.width: 1.5
        border.color: Theme.foregroundMuted

        Rectangle {
            x: 2.5
            y: 2.5
            width: Math.max(1, (parent.width - 5) * Math.min(1, gauge.value))
            height: parent.height - 5
            radius: 1
            color: gauge.fill
        }

        Rectangle {
            visible: gauge.limit < 1
            x: 2.5 + (parent.width - 5) * gauge.limit - 0.5
            y: 2.5
            width: 1
            height: parent.height - 5
            color: gauge.value >= gauge.limit ? Theme.backgroundMain : Theme.foregroundMuted
        }
    }

    Rectangle {
        anchors.left: body.right
        anchors.verticalCenter: parent.verticalCenter
        width: 2
        height: 5
        radius: 1
        color: Theme.foregroundMuted
    }
}
