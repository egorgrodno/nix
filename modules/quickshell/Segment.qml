import QtQuick

// A group of related modules on a bar.
Rectangle {
    default property alias content: row.data

    implicitWidth: row.implicitWidth
    height: parent.height
    radius: Theme.radius
    color: Theme.alpha(Theme.backgroundMain, 0.94)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.06)

    Row {
        id: row

        height: parent.height
    }
}
