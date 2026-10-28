import QtQuick

// How many decisions wait on the user: a number on a yellow pill.
Rectangle {
    id: pill

    property int count
    property int pixelSize: 12

    width: Math.max(height, label.implicitWidth + 10)
    height: pixelSize + 6
    radius: height / 2
    color: Theme.yellow

    BarText {
        id: label

        anchors.centerIn: parent
        text: `${pill.count}`
        color: Theme.backgroundMain
        font.pixelSize: pill.pixelSize
        font.weight: Font.DemiBold
    }
}
