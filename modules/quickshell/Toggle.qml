import QtQuick

// A switch, blue while on. The row around it takes the click and reports the
// hover.
Rectangle {
    id: toggle

    property bool checked
    property bool hovered

    width: 44
    height: 24
    radius: 6
    color: checked ? Theme.blue : hovered ? Theme.foregroundDark : Qt.rgba(1, 1, 1, 0.12)

    Behavior on color {
        ColorAnimation {
            duration: 150
            easing.type: Easing.OutQuad
        }
    }

    Rectangle {
        x: toggle.checked ? parent.width - width - 3 : 3
        y: 3
        width: 18
        height: 18
        radius: 4
        color: toggle.checked ? Theme.backgroundMain : Theme.foregroundMuted

        Behavior on x {
            NumberAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }
    }
}
