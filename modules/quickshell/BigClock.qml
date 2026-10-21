import QtQuick
import Quickshell

// The time over the date, large, for the lock screen and the greeter.
Column {
    spacing: 4

    SystemClock {
        id: time

        precision: SystemClock.Minutes
    }

    Figure {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.locale("C").toString(time.date, "HH:mm")
        font.pixelSize: 96
        color: Theme.alpha(Theme.foregroundStrong, 0.9)
    }

    BarText {
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.locale("C").toString(time.date, "dddd, d MMMM yyyy")
        font.pixelSize: 22
        color: Theme.alpha(Theme.foregroundStrong, 0.7)
    }
}
