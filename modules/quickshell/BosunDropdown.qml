pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic

// A compact button showing the current value, which opens a small menu of the
// values under it. The menu is an item of the panel's window, not a window of
// its own: a popup window would leave the panel's focus grab, and clear it. A
// press outside the menu closes it and goes no further. A list longer than
// the window scrolls. Enter,
// Space and Down open it from the keyboard, as does `show` for a pane's own
// key; Down, Up and the layout's down and up keys move; Enter and Space pick;
// Tab opens the `after` dropdown's menu instead; Escape closes it. Escape and a
// pick return the keyboard to where it was before `show`. It closes as the
// value changes, as focus leaves, as the button disables or hides, and with
// the panel.
Item {
    id: dropdown

    // What the button is for, in front of the value.
    property string name
    property var values: []
    property string current
    // Lit ahead of the values while `current` is empty: "default" for a
    // session on Claude Code's default, which the panel cannot resolve.
    property string fallback
    // What `fallback` reads as, when it can say more than the word: the model
    // or effort that default comes to.
    property string fallbackLabel
    // Keeps `fallback` in the menu while `current` is set, so a pick can go
    // back to it. Picking it emits "".
    property bool resettable: false
    // The menu's least width, and the button's greatest: a longer value
    // elides in the button.
    property real menuWidth: 0
    property real maxWidth: Infinity
    readonly property string lit: current || fallback
    readonly property var entries: fallback !== "" && (resettable || current === "") ? [fallback].concat(values) : values
    readonly property real rowHeight: 26
    property bool open: false
    property int index: 0
    // The dropdown whose menu Tab opens in place of this one's.
    property var after: null
    // Where the keyboard was before the menu took it.
    property Item home: null

    signal picked(string value)

    function label(value) {
        if (value === fallback && fallbackLabel)
            return fallbackLabel;
        return value === "" ? "default" : value;
    }

    // False while the button cannot be used. `from` is where Escape returns
    // the keyboard, else the item that has it now.
    function show(from) {
        if (!enabled || !visible)
            return false;
        home = from ?? Window.activeFocusItem;
        index = Math.max(0, entries.indexOf(lit));
        open = true;
        forceActiveFocus();
        return true;
    }

    function close() {
        open = false;
        if (home?.visible)
            home.forceActiveFocus();
    }

    function pick(value) {
        close();
        if (value !== lit)
            picked(value === fallback ? "" : value);
    }

    width: button.width
    height: 28
    activeFocusOnTab: true
    onCurrentChanged: open = false
    onIndexChanged: list.positionViewAtIndex(index, ListView.Contain)
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
        if (key === Qt.Key_Down || event.text === Host.directions.down)
            index = Math.min(index + 1, entries.length - 1);
        else if (key === Qt.Key_Up || event.text === Host.directions.up)
            index = Math.max(index - 1, 0);
        else if ([Qt.Key_Return, Qt.Key_Enter, Qt.Key_Space].includes(key))
            pick(entries[index]);
        else if (key === Qt.Key_Escape)
            close();
        else if (key === Qt.Key_Tab && after?.show(home) === true) {
            // The next menu has the keyboard, which closed this one.
        } else {
            // Tab moves on, and closes the menu as focus leaves.
            event.accepted = false;
        }
    }

    Rectangle {
        id: button

        width: Math.min(caption.implicitWidth + 20, dropdown.maxWidth)
        height: parent.height
        radius: Theme.radius - 4
        color: dropdown.open || mouse.containsMouse ? Theme.tint(0.12) : Theme.tint(0.06)
        border.width: 1
        border.color: dropdown.activeFocus ? Theme.blue : "transparent"
        opacity: dropdown.enabled ? 1 : 0.5

        BarText {
            id: caption

            anchors.centerIn: parent
            width: Math.min(implicitWidth, button.width - 20)
            elide: Text.ElideRight
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


    // A press anywhere in the window but the menu closes it and goes no
    // further, the button's included. It and the menu sit on the window's
    // content item rather than here, since `z` orders siblings only: the items
    // after this one in its pane, and the panel's own press area, would stack
    // above both and take the clicks.
    MouseArea {
        id: outside

        parent: dropdown.Window.contentItem
        anchors.fill: parent
        z: 1000
        visible: dropdown.open
        acceptedButtons: Qt.AllButtons
        // On release, so the release does not fall through to the item the
        // press was kept from.
        onReleased: dropdown.close()

        Rectangle {
            id: menu

            // Under the button, where it was as the menu opened.
            readonly property point origin: dropdown.open ? dropdown.mapToItem(outside, 0, dropdown.height + 4) : Qt.point(0, 0)

            // Kept inside the window, and short enough to scroll.
            x: Math.max(0, Math.min(origin.x, outside.width - width - 12))
            y: origin.y
            width: Math.max(button.width, dropdown.menuWidth)
            height: Math.min(dropdown.entries.length * dropdown.rowHeight, outside.height - y - 20) + 8
            radius: Theme.radius - 4
            color: Theme.backgroundRaised
            border.width: 1
            border.color: Theme.tint(0.12)

            // Takes presses on the menu's padding, below the entries.
            MouseArea {
                anchors.fill: parent
            }

            ListView {
                id: list

                x: 4
                y: 4
                width: menu.width - 8
                height: menu.height - 8
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: dropdown.entries

                ScrollBar.vertical: OverlayScrollBar {}

                delegate: Rectangle {
                    id: entry

                    required property string modelData
                    required property int index
                    readonly property bool isCurrent: modelData === dropdown.lit

                    width: ListView.view.width
                    height: dropdown.rowHeight
                    radius: Theme.radius - 5
                    color: entry.index === dropdown.index ? Theme.tint(0.08) : "transparent"

                    BarText {
                        x: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - 2 * x - (entry.isCurrent ? 24 : 0)
                        elide: Text.ElideRight
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
