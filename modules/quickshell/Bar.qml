import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Services.UPower

// Segments of related modules inside the strip the bar reserves, their outer
// edges in line with the windows' gaps.
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

    component Segment: Rectangle {
        default property alias content: row.data

        implicitWidth: row.implicitWidth
        height: parent.height
        radius: Theme.radius
        color: Theme.alpha(Theme.backgroundMain, 0.94)
        border.width: 1
        border.color: Qt.rgba(1, 1, 1, 0.06)

        Row {
            id: row

            height: parent.height
        }
    }

    Item {
        id: content

        anchors {
            fill: parent
            topMargin: 6
            bottomMargin: 6
            leftMargin: 20
            rightMargin: 20
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

            Segment {
                visible: UPower.displayDevice.isLaptopBattery

                Battery {}
            }

            Segment {
                Network {}

                Pill {
                    hoverable: false
                    tooltip: Stats.cpuTooltip
                    tooltipContent: Component {
                        CoreChart {}
                    }

                    Caption {
                        anchors.baseline: cpuFigure.baseline
                        text: "cpu"
                    }

                    CoreBars {
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Figure {
                        id: cpuFigure

                        anchors.verticalCenter: parent.verticalCenter
                        widest: "100%"
                        text: `${Stats.cpu}%`
                    }
                }

                Pill {
                    hoverable: false
                    tooltip: Stats.memoryTooltip

                    Caption {
                        anchors.baseline: ramFigure.baseline
                        text: "ram"
                    }

                    Meter {
                        anchors.verticalCenter: parent.verticalCenter
                        value: Stats.memory / 100
                    }

                    Figure {
                        id: ramFigure

                        anchors.verticalCenter: parent.verticalCenter
                        widest: "100%"
                        text: `${Stats.memory}%`
                    }
                }

                Pill {
                    tooltip: Stats.diskTooltip
                    onClicked: button => {
                        if (button === Qt.LeftButton)
                            Quickshell.execDetached([Programs.pcmanfm, "/"]);
                    }

                    Caption {
                        anchors.baseline: diskFigure.baseline
                        text: "disk"
                    }

                    Meter {
                        anchors.verticalCenter: parent.verticalCenter
                        value: Stats.disk / 100
                    }

                    // The stylesheet's intent; Waybar's disk module never sets the class.
                    Figure {
                        id: diskFigure

                        anchors.verticalCenter: parent.verticalCenter
                        widest: "100%"
                        text: `${Stats.disk}%`
                        color: Stats.disk >= 90 ? Theme.red : "#ffffff"
                    }
                }
            }

            Segment {
                Volume {}

                Tray {}
            }

            Segment {
                Clock {}

                Power {}
            }
        }
    }
}
