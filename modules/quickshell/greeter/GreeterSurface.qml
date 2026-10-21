import QtQuick
import Quickshell
import Quickshell.Wayland

// One screen of the greeter: the time over the date, the login card, and the
// keys along the bottom, which fade in together once the layout has applied.
// Every screen shows the one state, and whichever has the keyboard types into
// it. Up and Down step the user, Tab and Shift Tab the session.
PanelWindow {
    id: surface

    required property ShellScreen modelData
    // The Greeter that every screen shows.
    property var greeter

    screen: modelData
    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.backgroundMain
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-greeter"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Item {
        id: content

        anchors.fill: parent
        focus: true
        opacity: surface.greeter.ready ? 1 : 0
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: event => {
            switch (event.key) {
            case Qt.Key_Up:
                surface.greeter.stepUser(-1);
                break;
            case Qt.Key_Down:
                surface.greeter.stepUser(1);
                break;
            case Qt.Key_Tab:
                surface.greeter.stepSession(1);
                break;
            case Qt.Key_Backtab:
                surface.greeter.stepSession(-1);
                break;
            case Qt.Key_F11:
                surface.greeter.power("reboot");
                break;
            case Qt.Key_F12:
                surface.greeter.power("poweroff");
                break;
            default:
                event.accepted = surface.greeter.password.key(event);
                return;
            }
            event.accepted = true;
        }
        Keys.onReleased: event => {
            if (event.key === Qt.Key_CapsLock)
                surface.greeter.caps.update();
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        BigClock {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: card.top
            anchors.bottomMargin: 48
        }

        LoginCard {
            id: card

            // Its top fixed, so a message grows it downward only.
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            user: surface.greeter.user?.name ?? ""
            stepsUser: surface.greeter.users.length > 1
            session: surface.greeter.session?.name ?? ""
            stepsSession: surface.greeter.sessions.length > 1
            length: surface.greeter.password.text.length
            busy: surface.greeter.busy
            capsLock: surface.greeter.caps.locked
            message: surface.greeter.message
            messageColor: surface.greeter.messageError ? Theme.yellow : Theme.foregroundMuted
            onUserStepped: by => surface.greeter.stepUser(by)
            onSessionStepped: by => surface.greeter.stepSession(by)
        }

        // As tuigreet listed its own. A power key's hint asks for it again
        // while it waits, and a click on it counts as the key.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 32
            spacing: 28

            Repeater {
                model: [
                    {
                        key: "↑↓",
                        label: "User",
                        shown: surface.greeter.users.length > 1
                    },
                    {
                        key: "Tab",
                        label: "Session",
                        shown: surface.greeter.sessions.length > 1
                    },
                    {
                        key: "F11",
                        label: "Reboot",
                        verb: "reboot",
                        shown: true
                    },
                    {
                        key: "F12",
                        label: "Shut down",
                        verb: "poweroff",
                        shown: true
                    }
                ]

                Row {
                    id: hint

                    required property var modelData
                    readonly property bool armed: modelData.verb !== undefined && surface.greeter.armed === modelData.verb

                    visible: modelData.shown
                    spacing: 8

                    BarText {
                        id: keyLabel

                        text: hint.modelData.key
                        color: hint.armed ? Theme.yellow : Theme.foregroundMuted
                        font.family: Theme.fontMono
                        font.pixelSize: 14
                    }

                    BarText {
                        anchors.baseline: keyLabel.baseline
                        text: hint.armed ? `Press again to ${hint.modelData.label.toLowerCase()}` : hint.modelData.label
                        color: hint.armed ? Theme.yellow : Theme.foregroundMain
                        font.pixelSize: 14
                    }

                    TapHandler {
                        enabled: hint.modelData.verb !== undefined
                        onTapped: surface.greeter.power(hint.modelData.verb)
                    }
                }
            }
        }
    }
}
