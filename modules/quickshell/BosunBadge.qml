import QtQuick

// How many decisions wait on the user: a number on a yellow pill. It grows in
// as the first arrives, swells once as another does, and shrinks away with
// its last number once none waits.
Rectangle {
    id: pill

    property int count
    property int pixelSize: 12
    // The number it shows, the last above 0 while it shrinks away.
    property int shownCount: count
    // From 0, gone, to 1, whole.
    property real appear: count > 0 ? 1 : 0
    // Over 1 while it swells.
    property real swell: 1

    onCountChanged: {
        if (count <= 0)
            return;
        if (count > shownCount && shownCount > 0)
            swelling.restart();
        shownCount = count;
    }

    visible: appear > 0
    width: Math.max(height, label.implicitWidth + 10)
    height: pixelSize + 6
    radius: height / 2
    color: Theme.yellow
    opacity: appear
    scale: (0.5 + 0.5 * appear) * swell

    // As long as a panel takes to open.
    Behavior on appear {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutCubic
        }
    }

    SequentialAnimation {
        id: swelling

        NumberAnimation {
            target: pill
            property: "swell"
            to: 1.3
            duration: 100
            easing.type: Easing.OutCubic
        }

        NumberAnimation {
            target: pill
            property: "swell"
            to: 1
            duration: 150
            easing.type: Easing.InOutCubic
        }
    }

    BarText {
        id: label

        anchors.centerIn: parent
        text: `${pill.shownCount}`
        color: Theme.backgroundMain
        font.pixelSize: pill.pixelSize
        font.weight: Font.DemiBold
    }
}
