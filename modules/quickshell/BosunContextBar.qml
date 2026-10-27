import QtQuick

// A session's context window as a thin bar, filled as far as `used` reaches
// into `total`.
Rectangle {
    id: bar

    property var context: null

    implicitWidth: 56
    implicitHeight: 4
    radius: height / 2
    color: Theme.tint(0.1)

    Rectangle {
        width: bar.width * BosunLook.contextFill(bar.context)
        height: parent.height
        radius: parent.radius
        color: BosunLook.contextColor(bar.context)
    }
}
