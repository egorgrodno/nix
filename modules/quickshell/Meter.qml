import QtQuick

// A level from 0 to 1. Grey unless graded, when it turns yellow from 70% and
// red from 90%.
Rectangle {
    id: meter

    property real value
    property bool graded: true
    property color fill: Theme.foregroundMuted

    width: 28
    height: 4
    radius: 2
    color: Qt.rgba(1, 1, 1, 0.1)

    Rectangle {
        width: Math.max(parent.height, parent.width * Math.min(1, meter.value))
        height: parent.height
        radius: parent.radius
        color: meter.graded && meter.value >= 0.9 ? Theme.red : meter.graded && meter.value >= 0.7 ? Theme.yellow : meter.fill
    }
}
