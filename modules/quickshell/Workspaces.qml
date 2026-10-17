import QtQuick
import Quickshell
import Quickshell.Hyprland

// The screen's workspaces by number over a dot per window, up to four, and the
// focused one marked along the bottom edge. A workspace showing on another
// screen is not marked.
Row {
    id: workspaces

    required property HyprlandMonitor monitor

    Repeater {
        model: ScriptModel {
            values: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === workspaces.monitor).sort((a, b) => a.id - b.id)
        }

        Item {
            id: button

            required property HyprlandWorkspace modelData
            readonly property int windows: modelData.toplevels.values.length

            width: Math.max(40, label.implicitWidth + 24)
            height: parent.height

            Rectangle {
                anchors.fill: parent
                anchors.margins: 4
                radius: Theme.radius - 4
                color: button.modelData.urgent ? Theme.alpha(Theme.red, 0.6) : mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                        easing.type: Easing.OutQuad
                    }
                }
            }

            BarText {
                id: label

                anchors.horizontalCenter: parent.horizontalCenter
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -3
                text: button.modelData.name
                color: button.windows === 0 && !button.modelData.urgent ? Theme.foregroundMuted : "#ffffff"
                font.family: Theme.fontMono
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: label.bottom
                anchors.topMargin: 1
                spacing: 3

                Repeater {
                    model: Math.min(button.windows, 4)

                    Rectangle {
                        width: 3
                        height: 3
                        radius: 1.5
                        color: button.modelData.focused ? Theme.blue : Theme.foregroundMuted
                    }
                }
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 12
                height: 3
                topLeftRadius: 1.5
                topRightRadius: 1.5
                color: Theme.blue
                visible: button.modelData.focused
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                onClicked: button.modelData.activate()
            }
        }
    }
}
