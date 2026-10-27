pragma ComponentBehavior: Bound

import QtQuick

// A compact button showing the current value, which opens a small menu of the
// values under it. The menu is an item of the panel, not a window of its own:
// a popup window would leave the panel's focus grab, and clear it. Enter,
// Space and Down open it from the keyboard; Down, Up, j and k move; Enter and
// Space pick; Escape closes it. It closes as the value changes, as focus
// leaves, as the button disables or hides, and with the panel.
Item {
    id: dropdown

    // What the button is for, in front of the value.
    property string name
    property var values: []
    property string current
    // Lit ahead of the values while `current` is empty: "default" for a
    // session on Claude Code's default, which the panel cannot resolve.
    property string fallback
    readonly property string lit: current || fallback
    readonly property var entries: current === "" && fallback !== "" ? [fallback].concat(values) : values
    property bool open: false
    property int index: 0

    signal picked(string value)

    function label(value) {
        return value === "" ? "default" : value;
    }

    function show() {
        index = Math.max(0, entries.indexOf(lit));
        open = true;
        forceActiveFocus();
    }

    function pick(value) {
        open = false;
        if (value !== lit)
            picked(value);
    }

    width: button.width
    height: 28
    activeFocusOnTab: true
    onCurrentChanged: open = false
    onEnabledChanged: if (!enabled)
        open = false
    onVisibleChanged: if (!visible)
        open = false
    onActiveFocusChanged: if (!activeFocus)
        open = false

    Keys.onPressed: event => {
        const key = event.key;
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return;
        if (!open) {
            if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space, Qt.Key_Down].includes(key)) {
                show();
                event.accepted = true;
            }
            return;
        }
        event.accepted = true;
        if (key === Qt.Key_Down || event.text === "j")
            index = Math.min(index + 1, entries.length - 1);
        else if (key === Qt.Key_Up || event.text === "k")
            index = Math.max(index - 1, 0);
        else if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(key))
            pick(entries[index]);
        else if (key === Qt.Key_Escape)
            open = false;
        else {
            // Tab moves on, and closes the menu as focus leaves.
            event.accepted = false;
        }
    }

    Rectangle {
        id: button

        width: caption.implicitWidth + 20
        height: parent.height
        radius: Theme.radius - 4
        color: dropdown.open || mouse.containsMouse ? Theme.tint(0.12) : Theme.tint(0.06)
        border.width: 1
        border.color: dropdown.activeFocus ? Theme.blue : "transparent"
        opacity: dropdown.enabled ? 1 : 0.5

        BarText {
            id: caption

            anchors.centerIn: parent
            text: `${dropdown.name ? dropdown.name + "  " : ""}${dropdown.label(dropdown.lit)}  ${BosunLook.chevronDown}`
            font.pixelSize: 14
        }

        MouseArea {
            id: mouse

            anchors.fill: parent
            hoverEnabled: true
            onClicked: {
                if (dropdown.open)
                    dropdown.open = false;
                else
                    dropdown.show();
            }
        }
    }

    // A click anywhere else in the panel closes the menu and goes no further.
    MouseArea {
        x: -5000
        y: -5000
        z: 99
        width: 10000
        height: 10000
        visible: dropdown.open
        onClicked: dropdown.open = false
    }

    Rectangle {
        id: menu

        y: parent.height + 4
        z: 100
        width: Math.max(button.width, column.implicitWidth + 8)
        height: column.implicitHeight + 8
        visible: dropdown.open
        radius: Theme.radius - 4
        color: Theme.backgroundRaised
        border.width: 1
        border.color: Theme.tint(0.12)

        Column {
            id: column

            x: 4
            y: 4

            Repeater {
                model: dropdown.entries

                Rectangle {
                    id: entry

                    required property string modelData
                    required property int index
                    readonly property bool isCurrent: modelData === dropdown.lit

                    width: menu.width - 8
                    height: 26
                    radius: Theme.radius - 5
                    color: entry.index === dropdown.index ? Theme.tint(0.12) : "transparent"

                    BarText {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        text: dropdown.label(entry.modelData)
                        color: entry.isCurrent ? Theme.blue : Theme.foregroundStrong
                        font.pixelSize: 14
                    }

                    BarText {
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        visible: entry.isCurrent
                        text: BosunLook.check
                        color: Theme.blue
                        font.pixelSize: 14
                    }

                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        onEntered: dropdown.index = entry.index
                        onClicked: dropdown.pick(entry.modelData)
                    }
                }
            }
        }
    }
}
