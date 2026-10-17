import QtQuick
import Quickshell

// The instruments, in a strip along the bottom edge as tall as the top bar's,
// which leaves the top bar room to centre the workspaces.
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
            leftMargin: 20
            rightMargin: 20
        }

        Segment {
            anchors.right: parent.right

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

                Figure {
                    id: diskFigure

                    anchors.verticalCenter: parent.verticalCenter
                    widest: "100%"
                    text: `${Stats.disk}%`
                    color: Stats.disk >= 90 ? Theme.red : "#ffffff"
                }
            }
        }
    }
}
