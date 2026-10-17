import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Under the battery module: the charge, the power profile, the backlight and
// the charge limit. A click outside closes it, as Escape does.
PopupWindow {
    id: panel

    required property Battery module
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

    anchor.item: module
    anchor.rect.width: module.width
    anchor.rect.height: module.height + 4
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.SlideX
    implicitWidth: box.implicitWidth
    implicitHeight: box.implicitHeight
    color: "transparent"
    grabFocus: true
    visible: true

    Component.onCompleted: module.sample()

    Rectangle {
        id: box

        implicitWidth: 360
        implicitHeight: content.implicitHeight + 2 * 20
        color: Theme.backgroundMain
        border.color: Theme.blue
        border.width: 2
        radius: Theme.radius
        opacity: 0.95
        focus: true
        Keys.onEscapePressed: panel.visible = false

        Column {
            id: content

            x: 20
            y: 20
            width: parent.width - 40
            spacing: 20

            Column {
                spacing: 4

                BarText {
                    text: panel.module.text
                    font.pixelSize: 24
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

                        width: (content.width - profiles.spacing * (profiles.model.length - 1)) / profiles.model.length
                        height: 64
                        radius: Theme.radius
                        color: active ? Theme.blue : mouse.containsMouse ? Theme.backgroundLight : Theme.alpha(Theme.backgroundLight, 0.8)

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

            Item {
                width: content.width
                height: brightness.height

                Row {
                    id: brightness

                    spacing: 12

                    BarText {
                        id: sun

                        anchors.verticalCenter: parent.verticalCenter
                        text: "󰃠"
                        font.pixelSize: 20
                    }

                    Slider {
                        id: slider

                        anchors.verticalCenter: parent.verticalCenter
                        width: content.width - sun.width - percent.width - 2 * parent.spacing
                        height: 24
                        padding: 0
                        from: 1
                        to: 100
                        stepSize: 1
                        snapMode: Slider.SnapAlways
                        value: Backlight.percent
                        onMoved: Backlight.setPercent(value)

                        background: Rectangle {
                            y: (slider.height - height) / 2
                            width: slider.availableWidth
                            height: 6
                            radius: 3
                            color: Theme.backgroundLight

                            Rectangle {
                                width: slider.handle.x + slider.handle.width / 2
                                height: parent.height
                                radius: 3
                                color: Theme.blue
                            }
                        }

                        handle: Rectangle {
                            x: slider.visualPosition * (slider.availableWidth - width)
                            y: (slider.height - height) / 2
                            width: 18
                            height: 18
                            radius: 9
                            color: slider.pressed || slider.hovered ? Theme.foregroundLight : Theme.foregroundMain
                        }
                    }

                    BarText {
                        id: percent

                        anchors.verticalCenter: parent.verticalCenter
                        // As wide as 100%, so the slider keeps its length.
                        width: widest.advanceWidth
                        horizontalAlignment: Text.AlignRight
                        text: `${Backlight.percent}%`

                        TextMetrics {
                            id: widest

                            font: percent.font
                            text: "100%"
                        }
                    }
                }

                // A notch steps by 5, as on the volume module. The slider's own
                // wheel handling rounds a touchpad's fractions of a step away.
                MouseArea {
                    property int wheel: 0

                    anchors.fill: parent
                    acceptedButtons: Qt.NoButton
                    onWheel: event => {
                        wheel += event.angleDelta.y;
                        const steps = Math.trunc(wheel / 120);
                        if (steps !== 0) {
                            wheel -= steps * 120;
                            Backlight.setPercent(Math.max(1, Math.min(100, Backlight.percent + 5 * steps)));
                        }
                    }
                }
            }

            Item {
                width: content.width
                height: Math.max(limitText.implicitHeight, toggle.height)

                Column {
                    id: limitText

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    BarText {
                        text: "Charge limit"
                    }

                    // The thresholds the firmware holds, whatever the state file says.
                    BarText {
                        readonly property int start: parseInt(limitStart.text())
                        readonly property int end: parseInt(limitEnd.text())

                        text: end < 100 ? `Stops at ${end}%, resumes below ${start}%` : "Charges to 100%"
                        color: Theme.foregroundMuted
                        font.pixelSize: 14
                    }
                }

                Rectangle {
                    id: toggle

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: 44
                    height: 24
                    radius: height / 2
                    color: panel.limited ? Theme.blue : toggleMouse.containsMouse ? Theme.foregroundDark : Theme.backgroundLight

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }

                    Rectangle {
                        x: panel.limited ? parent.width - width - 3 : 3
                        y: 3
                        width: 18
                        height: 18
                        radius: 9
                        color: panel.limited ? Theme.backgroundMain : Theme.foregroundMuted

                        Behavior on x {
                            NumberAnimation {
                                duration: 150
                                easing.type: Easing.OutQuad
                            }
                        }
                    }
                }

                MouseArea {
                    id: toggleMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    enabled: !panel.limitBusy
                    onClicked: panel.toggleLimit()
                }
            }
        }
    }

    // The brightness keys change it behind the slider's back.
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

    FileView {
        id: limitStart

        path: `${panel.module.sysfs}/charge_control_start_threshold`
        blockAllReads: true
    }

    FileView {
        id: limitEnd

        path: `${panel.module.sysfs}/charge_control_end_threshold`
        blockAllReads: true
    }

    Process {
        id: limiter

        onExited: {
            limitOff.reload();
            limitStart.reload();
            limitEnd.reload();
            panel.limitBusy = false;
        }
    }
}
