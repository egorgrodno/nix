import QtQuick
import Quickshell

// Under the bell: do-not-disturb, then every notification as the popups' cards
// with their age, grouped by app, newest group first, and Clear. Opening it
// ends the popups, which it lists, and while it is open new notifications land
// here instead. Every group starts open.
Panel {
    id: panel

    // As tall as the strip between the bars allows, the list scrolling beyond.
    readonly property real listMax: (screen?.height ?? 800) - 2 * (Theme.barHeight + 4) - 2 * 20 - dnd.height - footer.height - 2 * 20
    // Entries by desktop entry, else app name, in the order of each app's
    // newest. A Map, as an object puts integer keys first.
    readonly property var groups: {
        const groups = new Map();
        for (const entry of Notifications.entries) {
            const key = entry.desktopEntry !== "" ? entry.desktopEntry : entry.appName;
            groups.set(key, [...(groups.get(key) ?? []), entry]);
        }
        return groups;
    }
    // Kept here, as the list destroys a group scrolled out of view.
    property var collapsed: []

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
        spacing: 12
        boundsBehavior: Flickable.StopAtBounds
        // Keys rather than the groups themselves: ScriptModel keeps the old
        // value of an item it moves, as a group with a new entry moves.
        model: ScriptModel {
            values: [...panel.groups.keys()]
        }

        // A removal drops contentHeight at once, while what follows eases up
        // and would be clipped meanwhile.
        Behavior on height {
            enabled: panel.settled

            NumberAnimation {
                duration: 200
                easing.type: Easing.OutExpo
            }
        }
        delegate: NotificationGroup {
            entries: panel.groups.get(modelData) ?? []
            expanded: !panel.collapsed.includes(modelData)
            slideIn: panel.settled
            onToggled: panel.collapsed = expanded ? [...panel.collapsed, modelData] : panel.collapsed.filter(k => k !== modelData)
        }

        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: 200
                easing.type: Easing.OutExpo
            }
        }

        // A group that moves to the top fades in there rather than crossing
        // the groups it passes.
        move: Transition {
            NumberAnimation {
                property: "opacity"
                from: 0
                to: 1
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
