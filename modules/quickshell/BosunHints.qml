pragma ComponentBehavior: Bound

import QtQuick

// Keycaps, each run of them beside what it does.
Row {
    id: hints

    // [{ keys: ["a", "a"], text: "approve" }, …]
    property var model: []

    spacing: 16

    Repeater {
        model: hints.model

        Row {
            id: hint

            required property var modelData

            spacing: 4

            Repeater {
                model: hint.modelData.keys

                Rectangle {
                    id: cap

                    required property string modelData

                    width: Math.max(20, capText.implicitWidth + 10)
                    height: 20
                    radius: 4
                    color: "transparent"
                    border.width: 1
                    border.color: Theme.tint(0.2)

                    BarText {
                        id: capText

                        anchors.centerIn: parent
                        text: cap.modelData
                        color: Theme.foregroundMuted
                        font.family: Theme.fontMono
                        font.pixelSize: 12
                    }
                }
            }

            Caption {
                height: 20
                verticalAlignment: Text.AlignVCenter
                leftPadding: 2
                text: hint.modelData.text
            }
        }
    }
}
