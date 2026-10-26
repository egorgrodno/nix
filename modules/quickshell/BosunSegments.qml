pragma ComponentBehavior: Bound

import QtQuick

// One button per value, joined, with the current one lit in blue.
Rectangle {
    id: segments

    property var values: []
    property string current

    signal picked(string value)

    width: row.implicitWidth + 4
    height: 28
    radius: Theme.radius - 4
    color: Theme.tint(0.06)
    opacity: enabled ? 1 : 0.5

    Row {
        id: row

        x: 2
        anchors.verticalCenter: parent.verticalCenter

        Repeater {
            model: segments.values

            Rectangle {
                id: segment

                required property string modelData
                readonly property bool lit: modelData === segments.current

                width: label.implicitWidth + 20
                height: 24
                radius: Theme.radius - 5
                color: lit ? Theme.blue : mouse.containsMouse ? Theme.tint(0.12) : "transparent"

                BarText {
                    id: label

                    anchors.centerIn: parent
                    text: segment.modelData
                    color: segment.lit ? Theme.backgroundMain : Theme.foregroundStrong
                    font.pixelSize: 14
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: if (!segment.lit)
                        segments.picked(segment.modelData)
                }
            }
        }
    }
}
