import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Along the bottom edge, in a strip as tall as the top bar's: the apps menu,
// then cpu, ram, disk and gpu in the left corner, and the tray, bluetooth,
// volume, battery, clock and power in the right.
PanelWindow {
    required property ShellScreen modelData

    screen: modelData
    anchors {
        bottom: true
        left: true
        right: true
    }
    implicitHeight: Theme.barHeight
    exclusiveZone: Theme.barHeight
    color: "transparent"

    Item {
        anchors {
            fill: parent
            topMargin: 6
            bottomMargin: 6
            leftMargin: Theme.outerGap
            rightMargin: Theme.outerGap
        }

        Row {
            height: parent.height
            spacing: 8

            Segment {
                Apps {}
            }

            Segment {
                Pill {
                    hoverable: false
                    tooltipContent: Component {
                        CpuTip {}
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
                    tooltipContent: Component {
                        MemoryTip {}
                    }

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
                    tooltipContent: Component {
                        DiskTip {}
                    }
                    onClicked: button => {
                        if (button === Qt.LeftButton)
                            Launcher.run([Programs.pcmanfm, "/"]);
                    }

                    Caption {
                        anchors.baseline: diskFigure.baseline
                        text: "disk"
                    }

                    Meter {
                        anchors.verticalCenter: parent.verticalCenter
                        value: Stats.disk / 100
                    }

                    Figure {
                        id: diskFigure

                        anchors.verticalCenter: parent.verticalCenter
                        widest: "100%"
                        text: `${Stats.disk}%`
                        color: Stats.diskFull ? Theme.red : Theme.foregroundStrong
                    }
                }

                Pill {
                    id: gpu

                    visible: Gpus.primary !== null && !isNaN(Gpus.primary.busy)
                    hoverable: false
                    tooltipContent: Component {
                        GpuTip {}
                    }

                    Caption {
                        anchors.baseline: gpuFigure.baseline
                        text: "gpu"
                    }

                    Meter {
                        anchors.verticalCenter: parent.verticalCenter
                        value: (Gpus.primary?.busy ?? 0) / 100
                    }

                    Figure {
                        id: gpuFigure

                        anchors.verticalCenter: parent.verticalCenter
                        widest: "100%"
                        text: `${Gpus.primary?.busy ?? 0}%`
                    }
                }
            }
        }

        Row {
            anchors.right: parent.right
            height: parent.height
            spacing: 8

            // A hidden segment hides its modules too, so each one that can
            // empty takes its modules' condition rather than following them.
            // The tray leads, so a new icon grows into the empty middle and
            // moves no other module.
            Segment {
                visible: tray.items.length > 0

                Tray {
                    id: tray
                }
            }

            Segment {
                BluetoothToggle {
                    id: bluetooth

                    joinedRight: true
                }

                Volume {
                    joinedLeft: bluetooth.visible
                }
            }

            Segment {
                visible: UPower.displayDevice.isLaptopBattery

                Battery {}
            }

            Segment {
                Tasks {
                    id: tasks

                    joinedRight: true
                }

                Clock {
                    joinedLeft: tasks.visible
                }

                Power {}
            }
        }
    }
}
