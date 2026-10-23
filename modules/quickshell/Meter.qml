import QtQuick

// A level from 0 to 1.
Rectangle {
    id: meter

    property real value
    property bool graded: true
    property color fill: Theme.blue

    width: 28
    height: 4
    radius: 2
    color: Theme.tint(0.1)

    Rectangle {
        width: Math.max(parent.height, parent.width * Math.min(1, meter.value))
        height: parent.height
        radius: parent.radius
        color: meter.graded ? Stats.loadColor(meter.value, meter.fill) : meter.fill
    }
}
