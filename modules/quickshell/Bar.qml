import QtQuick
import Quickshell
import Quickshell.Hyprland

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
    color: Theme.alpha(Theme.backgroundMain, 0.3)

    Item {
        id: content

        anchors {
            fill: parent
            topMargin: 8
            bottomMargin: 8
            leftMargin: 20
            rightMargin: 20
        }

        WindowTitle {
            id: title

            monitor: bar.monitor
            maxWidth: right.x - 12 - centre.width - 12
        }

        // Centred on the bar unless that would crowd a side, as GTK places a
        // box's centre widget. Each side keeps the 12 px margin of its module
        // nearest the centre.
        Row {
            id: centre

            x: Math.max(title.visible ? title.width + 12 : 0, Math.min((content.width - width) / 2, right.x - 12 - width))
            height: parent.height
            leftPadding: 6
            rightPadding: 6
            spacing: 12

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
            spacing: 12

            Battery {}

            Network {}

            // One fill under all three, since two translucent fills meeting on
            // a fractional pixel leave a seam.
            Rectangle {
                implicitWidth: stats.implicitWidth
                height: parent.height
                radius: height / 2
                color: Theme.alpha(Theme.backgroundLight, 0.8)

                Row {
                    id: stats

                    height: parent.height

                    Pill {
                        fill: "transparent"
                        hoverable: false
                        rightPadding: 8
                        text: `CPU ${Stats.cpu}%`
                        tooltip: Stats.cpuTooltip
                    }

                    Pill {
                        fill: "transparent"
                        hoverable: false
                        leftPadding: 8
                        rightPadding: 8
                        text: `RAM ${Stats.memory}%`
                        tooltip: Stats.memoryTooltip
                    }

                    Pill {
                        fill: Theme.alpha(Theme.backgroundLight, 0)
                        leftPadding: 8
                        roundLeft: false
                        text: `DISK ${Stats.disk}%`
                        // The stylesheet's intent; Waybar's disk module never sets the class.
                        textColor: Stats.disk >= 90 ? Theme.red : "#ffffff"
                        tooltip: Stats.diskTooltip
                        onClicked: button => {
                            if (button === Qt.LeftButton)
                                Quickshell.execDetached([Programs.pcmanfm, "/"]);
                        }
                    }
                }
            }

            Volume {}

            Tray {}

            Clock {}

            Power {}
        }
    }
}
