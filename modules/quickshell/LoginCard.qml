import QtQuick

// The box the lock screen and the greeter share, in a panel's colours: the
// user, the password as dots, the session where there is one to pick, Caps
// Lock while it is on, and a line for PAM's messages. Arrows beside the user
// and the session step them where there are others. The card takes no keys;
// its owner does.
Rectangle {
    id: card

    property string user
    property bool stepsUser: false
    // Empty on the lock screen.
    property string session: ""
    property bool stepsSession: false
    property int length: 0
    property bool busy: false
    property bool capsLock: false
    property string message: ""
    property color messageColor: Theme.yellow

    signal userStepped(int by)
    signal sessionStepped(int by)

    // A label between arrows that step it, or plain without others to step to.
    component Stepper: Item {
        id: stepper

        property string text
        property bool steps: false
        property color textColor: Theme.foregroundStrong
        property int pixelSize: 16

        signal stepped(int by)

        implicitHeight: 28

        Repeater {
            model: stepper.steps ? [-1, 1] : []

            BarText {
                id: arrow

                required property int modelData

                anchors.verticalCenter: parent.verticalCenter
                x: modelData < 0 ? 0 : stepper.width - width
                text: modelData < 0 ? "\u{F0141}" : "\u{F0142}"
                font.pixelSize: 20
                color: hover.hovered ? Theme.foregroundStrong : Theme.foregroundMuted

                HoverHandler {
                    id: hover
                }

                TapHandler {
                    onTapped: stepper.stepped(arrow.modelData)
                }
            }
        }

        BarText {
            anchors.centerIn: parent
            width: parent.width - 56
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: stepper.text
            color: stepper.textColor
            font.pixelSize: stepper.pixelSize
        }
    }

    implicitWidth: 360
    implicitHeight: column.implicitHeight + 48
    radius: Theme.radius
    color: Theme.alpha(Theme.backgroundMain, 0.97)
    border.color: Theme.tint(0.08)
    border.width: 1

    Column {
        id: column

        x: 24
        y: 24
        width: parent.width - 48
        spacing: 14

        Stepper {
            width: parent.width
            text: card.user
            steps: card.stepsUser
            pixelSize: 18
            onStepped: by => card.userStepped(by)
        }

        PasswordField {
            width: parent.width
            length: card.length
            busy: card.busy
        }

        Stepper {
            width: parent.width
            visible: card.session !== ""
            text: card.session
            steps: card.stepsSession
            textColor: Theme.foregroundMuted
            pixelSize: 14
            onStepped: by => card.sessionStepped(by)
        }

        BarText {
            width: parent.width
            visible: card.capsLock
            horizontalAlignment: Text.AlignHCenter
            text: "\u{F0632}  Caps Lock is on"
            color: Theme.yellow
            font.pixelSize: 14
        }

        BarText {
            width: parent.width
            visible: text !== ""
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: card.message
            color: card.messageColor
            font.pixelSize: 14
        }
    }
}
