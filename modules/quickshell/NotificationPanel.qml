import QtQuick
import Quickshell

// Under the bell: do-not-disturb, then every notification newest first, as the
// popups' cards with their age, and Clear. Opening it ends the popups, which
// it lists, and while it is open new notifications land here instead.
Panel {
    id: panel

    // As tall as the strip between the bars allows, the list scrolling beyond.
    readonly property real listMax: (screen?.height ?? 800) - 2 * (Theme.barHeight + 4) - 2 * 20 - dnd.height - footer.height - 2 * 20

    Component.onCompleted: Notifications.panelOpened()
    Component.onDestruction: Notifications.panelClosed()

    Item {
        id: dnd

        width: panel.contentWidth
        height: Math.max(dndTexts.implicitHeight, dndToggle.height)

        MouseArea {
            id: dndMouse

            anchors.fill: parent
            hoverEnabled: true
            onClicked: Notifications.dnd = !Notifications.dnd
        }

        Column {
            id: dndTexts

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - dndToggle.width - 12
            spacing: 4

            BarText {
                text: "Do not disturb"
            }

            BarText {
                width: parent.width
                elide: Text.ElideRight
                color: Theme.foregroundMuted
                font.pixelSize: 14
                text: "Only critical notifications pop up"
            }
        }

        Toggle {
            id: dndToggle

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            checked: Notifications.dnd
            hovered: dndMouse.containsMouse
        }
    }

    ListView {
        id: list

        width: panel.contentWidth
        height: Math.min(contentHeight, panel.listMax)
        visible: count > 0
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        model: ScriptModel {
            // An array rather than the list property, which it cannot take.
            values: [...Notifications.entries]
        }
        delegate: NotificationCard {
            showTime: true
            slideIn: panel.settled
            fill: Qt.rgba(1, 1, 1, 0.04)
        }

        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: 200
                easing.type: Easing.OutExpo
            }
        }

        remove: Transition {
            NumberAnimation {
                property: "x"
                to: list.width
                duration: 200
                easing.type: Easing.OutExpo
            }

            NumberAnimation {
                property: "opacity"
                to: 0
                duration: 200
                easing.type: Easing.OutExpo
            }
        }
    }

    Item {
        id: footer

        width: panel.contentWidth
        height: clear.height

        Caption {
            anchors.verticalCenter: parent.verticalCenter
            visible: list.count === 0
            text: "No notifications"
        }

        TextButton {
            id: clear

            anchors.right: parent.right
            visible: list.count > 0
            text: "Clear"
            onClicked: Notifications.clear()
        }
    }
}
