import QtQuick

// Blue text that opens what it names, strong under the pointer.
BarText {
    id: link

    readonly property bool hovered: hover.hovered

    signal clicked

    color: hovered ? Theme.foregroundStrong : Theme.blue
    font.pixelSize: 14

    HoverHandler {
        id: hover

        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        onTapped: link.clicked()
    }
}
