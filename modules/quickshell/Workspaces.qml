import QtQuick
import Quickshell
import Quickshell.Hyprland

// The screen's workspaces by number. Waybar's "active" is the focused one, so
// a workspace showing on another screen is not lit.
Row {
    id: workspaces

    required property HyprlandMonitor monitor

    Repeater {
        model: ScriptModel {
            values: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === workspaces.monitor).sort((a, b) => a.id - b.id)
        }

        Rectangle {
            id: button

            required property HyprlandWorkspace modelData
            readonly property bool empty: modelData.toplevels.values.length === 0

            width: 32 + Math.max(16, label.implicitWidth)
            height: parent.height
            radius: height / 2
            color: modelData.urgent ? Theme.red : modelData.focused || mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.08) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }

            BarText {
                id: label

                anchors.centerIn: parent
                text: button.modelData.name
                color: button.empty && !button.modelData.urgent ? Theme.foregroundMuted : "#ffffff"

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                        easing.type: Easing.OutQuad
                    }
                }
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
