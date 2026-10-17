import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower

// Segments of related modules inside the strip the bar reserves, their outer
// edges in line with the windows' gaps. The instruments are on the bottom bar.
PanelWindow {
    id: bar

    required property ShellScreen modelData
    readonly property HyprlandMonitor monitor: Hyprland.monitorFor(screen)

    screen: modelData
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
    color: "transparent"

    Item {
        id: content

        anchors {
            fill: parent
            topMargin: 6
            bottomMargin: 6
            leftMargin: Theme.outerGap
            rightMargin: Theme.outerGap
        }

        // A hidden segment hides its modules too, so each one that can empty
        // takes its modules' condition rather than following them.
        Segment {
            id: title

            visible: windowTitle.title !== ""

            WindowTitle {
                id: windowTitle

                monitor: bar.monitor
                maxWidth: right.x - 8 - centre.width - 8
            }
        }

        // Centred on the bar unless that would crowd a side, as GTK places a
        // box's centre widget.
        Segment {
            id: centre

            x: Math.max(title.visible ? title.width + 8 : 0, Math.min((content.width - width) / 2, right.x - 8 - width))

            Submap {}

            Workspaces {
                monitor: bar.monitor
                height: parent.height
            }
        }

        Row {
            id: right

            anchors.right: parent.right
            height: parent.height
            spacing: 8

            // First, so a new icon grows into the room beside the workspaces
            // and moves no other module.
            Segment {
                visible: tray.items.length > 0

                Tray {
                    id: tray
                }
            }

            Segment {
                visible: UPower.displayDevice.isLaptopBattery

                Battery {}
            }

            Segment {
                Volume {}

                BluetoothToggle {}
            }

            Segment {
                Clock {}

                Power {}
            }
        }
    }
}
