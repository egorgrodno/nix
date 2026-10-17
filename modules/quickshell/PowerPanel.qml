import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Under the battery module: the charge, the power profile, the backlight and
// the charge limit.
Panel {
    id: panel

    // On unless the off file exists. While a toggle runs, the state it asked for.
    property bool limitBusy: false
    property bool limitTarget
    readonly property bool limited: limitBusy ? limitTarget : !limitOff.loaded

    function toggleLimit() {
        limitTarget = !limited;
        limitBusy = true;
        limiter.command = [Programs.systemctl, "start", `charge-limit@${limitTarget ? "on" : "off"}.service`];
        limiter.running = true;
    }

    Component.onCompleted: {
        module.sample();
        module.readLimits();
    }

    // A wheel notch moves it by wheelStep. The Slider's own wheel handling
    // rounds a touchpad's fractions of a step away.
    component PanelSlider: Slider {
        id: slider

        property real wheelStep: stepSize
        property int wheel: 0

        // A value the user chose, by dragging, clicking or the wheel.
        signal picked(real value)

        height: 24
        padding: 0
        stepSize: 1
        snapMode: Slider.SnapAlways
        onMoved: picked(value)

        background: Rectangle {
            y: (slider.height - height) / 2
            width: slider.availableWidth
            height: 4
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.12)

            Rectangle {
                width: slider.handle.x + slider.handle.width / 2
                height: parent.height
                radius: 2
                color: Theme.blue
            }
        }

        handle: Rectangle {
            x: slider.visualPosition * (slider.availableWidth - width)
            y: (slider.height - height) / 2
            width: 6
            height: 20
            radius: 2
            color: slider.pressed || slider.hovered ? Theme.foregroundLight : Theme.foregroundMain
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.NoButton
            onWheel: event => {
                slider.wheel += event.angleDelta.y;
                const steps = Math.trunc(slider.wheel / 120);
                if (steps !== 0) {
                    slider.wheel -= steps * 120;
                    slider.picked(Math.max(slider.from, Math.min(slider.to, slider.value + steps * slider.wheelStep)));
                }
            }
        }
    }

    Column {
        width: panel.contentWidth
        spacing: 8

        Figure {
            text: `${panel.module.capacity}%`
            font.pixelSize: 32
        }

        // The charge, and the band the charge limit holds it in.
        Rectangle {
            width: parent.width
            height: 8
            radius: 2
            color: Qt.rgba(1, 1, 1, 0.1)

            Rectangle {
                width: parent.width * Math.min(1, panel.module.capacity / 100)
                height: parent.height
                radius: 2
                color: panel.module.status === "Charging" ? Theme.green : panel.module.capacity <= 10 ? Theme.red : panel.module.capacity <= 20 ? Theme.yellow : Theme.foregroundMain
            }

            Rectangle {
                visible: panel.module.chargeEnd < 100
                x: parent.width * panel.module.chargeStart / 100
                width: parent.width * (panel.module.chargeEnd - panel.module.chargeStart) / 100
                height: parent.height
                color: Theme.alpha(Theme.blue, 0.6)
            }
        }

        BarText {
            text: {
                const b = panel.module;
                switch (b.status) {
                case "Discharging":
                    return b.time === "" ? "Discharging" : `Empty in ${b.time}`;
                case "Charging":
                    return b.time === "" ? "Charging" : `Full in ${b.time}`;
                case "Plugged":
                    return "Plugged in, not charging";
                default:
                    return "Full";
                }
            }
            color: Theme.foregroundMuted
            font.pixelSize: 14
        }
    }

    Row {
        id: profiles

        readonly property var model: [
            {
                profile: PowerProfile.PowerSaver,
                icon: "󰌪",
                label: "Power saver"
            },
            {
                profile: PowerProfile.Balanced,
                icon: "󰗑",
                label: "Balanced"
            },
            {
                profile: PowerProfile.Performance,
                icon: "󰓅",
                label: "Performance"
            }
        ].filter(p => p.profile !== PowerProfile.Performance || PowerProfiles.hasPerformanceProfile)

        spacing: 8

        Repeater {
            model: profiles.model

            Rectangle {
                id: button

                required property var modelData
                readonly property bool active: PowerProfiles.profile === modelData.profile
                readonly property color textColor: active ? Theme.backgroundMain : "#ffffff"

                width: (panel.contentWidth - profiles.spacing * (profiles.model.length - 1)) / profiles.model.length
                height: 64
                radius: Theme.radius
                color: active ? Theme.blue : mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                        easing.type: Easing.OutQuad
                    }
                }

                Column {
                    anchors.centerIn: parent
                    spacing: 4

                    BarText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: button.modelData.icon
                        color: button.textColor
                        font.pixelSize: 20
                    }

                    BarText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: button.modelData.label
                        color: button.textColor
                        font.pixelSize: 14
                    }
                }

                MouseArea {
                    id: mouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: PowerProfiles.profile = button.modelData.profile
                }
            }
        }
    }

    Row {
        spacing: 12

        BarText {
            id: sun

            anchors.verticalCenter: parent.verticalCenter
            text: "󰃠"
            font.pixelSize: 20
        }

        PanelSlider {
            anchors.verticalCenter: parent.verticalCenter
            width: panel.contentWidth - sun.width - percent.width - 2 * parent.spacing
            from: 1
            to: 100
            // As on the volume module.
            wheelStep: 5
            value: Backlight.percent
            onPicked: value => Backlight.setPercent(value)
        }

        // As wide as 100%, so the slider keeps its length.
        Figure {
            id: percent

            anchors.verticalCenter: parent.verticalCenter
            horizontalAlignment: Text.AlignRight
            widest: "100%"
            text: `${Backlight.percent}%`
        }
    }

    // Lowers the backlight and brightens the pixels to make up for it.
    Column {
        width: panel.contentWidth
        spacing: 8
        visible: Backlight.abm >= 0

        Item {
            width: parent.width
            height: abmTitle.implicitHeight

            BarText {
                id: abmTitle

                text: "Adaptive backlight"
            }

            BarText {
                anchors.right: parent.right
                anchors.baseline: abmTitle.baseline
                text: Backlight.abm === 0 ? "Off" : `Level ${Backlight.abm}`
                color: Theme.foregroundMuted
                font.pixelSize: 14
            }
        }

        PanelSlider {
            width: parent.width
            from: 0
            to: 4
            value: Backlight.abm
            onPicked: value => Backlight.setAbm(Math.round(value))
        }
    }

    Item {
        width: panel.contentWidth
        height: Math.max(limitText.implicitHeight, toggle.height)

        Column {
            id: limitText

            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            BarText {
                text: "Charge limit"
            }

            BarText {
                text: panel.module.chargeEnd < 100 ? `Stops at ${panel.module.chargeEnd}%, resumes below ${panel.module.chargeStart}%` : "Charges to 100%"
                color: Theme.foregroundMuted
                font.pixelSize: 14
            }
        }

        Toggle {
            id: toggle

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: panel.limited
            hovered: toggleMouse.containsMouse
        }

        MouseArea {
            id: toggleMouse

            anchors.fill: parent
            hoverEnabled: true
            enabled: !panel.limitBusy
            onClicked: panel.toggleLimit()
        }
    }

    // The brightness keys and TLP's profile switches change the sliders' values
    // behind their backs.
    Timer {
        interval: 1000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: Backlight.read()
    }

    FileView {
        id: limitOff

        path: "/var/lib/charge-limit/off"
        blockAllReads: true
        printErrors: false
    }

    Process {
        id: limiter

        onExited: {
            limitOff.reload();
            panel.module.readLimits();
            panel.limitBusy = false;
        }
    }
}
