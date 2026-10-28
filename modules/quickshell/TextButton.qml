import QtQuick

// A small button, lit while `lit` is set, as a confirmation waits.
Rectangle {
    id: button

    property alias text: label.text
    property color fill: Theme.tint(0.06)
    property color hoverFill: Theme.tint(0.12)
    property bool lit: false
    property color textColor: Theme.foregroundStrong
    property color litTextColor: textColor
    readonly property bool hovered: mouse.containsMouse

    signal clicked

    width: label.implicitWidth + 20
    height: 28
    radius: Theme.radius - 4
    color: lit || mouse.containsMouse ? hoverFill : fill

    Behavior on color {
        ColorAnimation {
            duration: 150
            easing.type: Easing.OutQuad
        }
    }

    BarText {
        id: label

        anchors.centerIn: parent
        color: !button.enabled ? Theme.foregroundMuted : button.lit || mouse.containsMouse ? button.litTextColor : button.textColor
        font.pixelSize: 14
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        onClicked: button.clicked()
    }
}
