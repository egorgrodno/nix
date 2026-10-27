import QtQuick

// A small round button over a scrolling view's corner that takes it to its
// newest entry. It fades in while `shown` is set, and takes no clicks while
// it is out.
Rectangle {
    id: button

    property bool shown: false
    // The arrow's glyph: down in a conversation, up in the Log.
    property string glyph: BosunLook.arrowDown

    signal clicked

    width: 32
    height: 32
    radius: width / 2
    opacity: shown ? 1 : 0
    visible: opacity > 0
    color: Theme.backgroundRaised
    border.width: 1
    border.color: Theme.tint(mouse.containsMouse ? 0.3 : 0.12)

    Behavior on opacity {
        NumberAnimation {
            duration: 180
            easing.type: Easing.OutCubic
        }
    }

    Behavior on border.color {
        ColorAnimation {
            duration: 150
            easing.type: Easing.OutQuad
        }
    }

    BarText {
        anchors.centerIn: parent
        text: button.glyph
        color: Theme.foregroundStrong
        font.pixelSize: 18
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        enabled: button.shown
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: button.clicked()
    }
}
