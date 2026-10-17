import QtQuick

// A small button, lit while `lit` is set, as a confirmation waits.
Rectangle {
    id: button

    property alias text: label.text
    property color hoverFill: Qt.rgba(1, 1, 1, 0.12)
    property bool lit: false

    signal clicked

    width: label.implicitWidth + 20
    height: 28
    radius: Theme.radius - 4
    color: lit || mouse.containsMouse ? hoverFill : Qt.rgba(1, 1, 1, 0.06)

    Behavior on color {
        ColorAnimation {
            duration: 150
            easing.type: Easing.OutQuad
        }
    }

    BarText {
        id: label

        anchors.centerIn: parent
        color: button.enabled ? "#ffffff" : Theme.foregroundMuted
        font.pixelSize: 14
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        onClicked: button.clicked()
    }
}
