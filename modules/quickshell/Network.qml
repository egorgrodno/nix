import QtQuick
import Quickshell

// Upload over download, as rates beside a minute of history.
Pill {
    visible: Stats.offline || Stats.up !== ""
    onClicked: button => {
        if (button === Qt.LeftButton)
            Quickshell.execDetached([Programs.nmConnectionEditor]);
    }

    BarText {
        anchors.verticalCenter: parent.verticalCenter
        visible: Stats.offline
        text: "⚠ No network"
        color: Theme.yellow
    }

    Spark {
        anchors.verticalCenter: parent.verticalCenter
        visible: !Stats.offline
        up: Stats.upHistory
        down: Stats.downHistory
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter
        visible: !Stats.offline

        Repeater {
            model: [
                {
                    icon: "\u{F0737}",
                    rate: Stats.up
                },
                {
                    icon: "\u{F072E}",
                    rate: Stats.down
                }
            ]

            Row {
                required property var modelData

                spacing: 4

                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: parent.modelData.icon
                    color: Theme.foregroundMuted
                    font.pixelSize: 12
                }

                Figure {
                    widest: "999 Kb/s"
                    text: parent.modelData.rate
                    font.pixelSize: 13
                }
            }
        }
    }
}
