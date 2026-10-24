import QtQuick

// A password as dots, one per character, the latest at the right edge once
// they fill the field. It holds no text: the owner's KeyBuffer does. Blue
// while its window has the keyboard and the password can be typed; while it
// is checked, the dots pulse instead.
Rectangle {
    id: field

    property int length: 0
    property bool busy: false
    property string placeholder: "Password"

    implicitWidth: 300
    implicitHeight: 40
    radius: Theme.radius - 4
    color: Theme.tint(0.06)
    border.width: 1
    border.color: Window.active && !field.busy ? Theme.blue : Theme.tint(0.12)
    clip: true

    Behavior on border.color {
        ColorAnimation {
            duration: 150
            easing.type: Easing.OutQuad
        }
    }

    BarText {
        anchors.centerIn: parent
        visible: field.length === 0
        text: field.placeholder
        color: Theme.foregroundMuted
        font.pixelSize: 14
    }

    Row {
        id: dots

        anchors.verticalCenter: parent.verticalCenter
        // Centred until the dots outgrow the field, then right-aligned.
        x: Math.min((parent.width - width) / 2, parent.width - 14 - width)
        spacing: 6

        SequentialAnimation on opacity {
            running: field.busy
            loops: Animation.Infinite
            onStopped: dots.opacity = 1

            NumberAnimation {
                to: 0.3
                duration: 450
                easing.type: Easing.InOutQuad
            }

            NumberAnimation {
                to: 1
                duration: 450
                easing.type: Easing.InOutQuad
            }
        }

        Repeater {
            model: field.length

            Rectangle {
                width: 8
                height: 8
                radius: 4
                color: Theme.foregroundStrong
            }
        }
    }
}
