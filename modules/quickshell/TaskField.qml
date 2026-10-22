import QtQuick
import QtQuick.Controls.Basic

// Todoist's Quick Add, which reads dates, #projects, /sections, @labels and p1
// to p4 out of the text, each marked behind it in a colour as it is typed. A
// task it leaves without a date takes `day`, if any.
TextField {
    id: field

    // An ISO date, or "" for none.
    property string day: ""
    readonly property var tokens: QuickAdd.tokens(text)

    function tokenColor(token) {
        switch (token.kind) {
        case "priority":
            return [Theme.foregroundMuted, Theme.foregroundMuted, Theme.blue, Theme.yellow, Theme.red][token.priority];
        case "date":
            return Theme.green;
        case "label":
            return Theme.cyan;
        }
        return Theme.magenta;
    }

    height: 34
    leftPadding: 36
    rightPadding: 10
    topPadding: 0
    bottomPadding: 0
    verticalAlignment: TextInput.AlignVCenter
    placeholderText: {
        if (!day)
            return "Add a task";
        const label = Todoist.dayLabel(day);
        return `Add a task for ${/^(Today|Tomorrow|Yesterday)$/.test(label) ? label.toLowerCase() : label}`;
    }
    placeholderTextColor: Theme.foregroundMuted
    color: Theme.foregroundStrong
    selectionColor: Theme.blue
    selectedTextColor: Theme.backgroundMain
    font.family: Theme.fontUI
    font.pixelSize: 14
    onAccepted: {
        const text = field.text.trim();
        if (text === "")
            return;
        Todoist.add(text, day);
        field.text = "";
    }

    background: Rectangle {
        radius: Theme.radius - 4
        color: Theme.tint(0.06)
        border.width: 1
        border.color: field.activeFocus ? Theme.blue : Theme.tint(0.12)

        // Clipped to the text's room, which scrolls under it, and where
        // positionToRectangle counts from.
        Item {
            x: field.leftPadding
            width: field.width - field.leftPadding - field.rightPadding
            height: parent.height
            clip: true

            Repeater {
                model: field.tokens

                Rectangle {
                    required property var modelData
                    // Read again whenever the cursor moves, as the text then
                    // scrolls: positionToRectangle notifies nothing.
                    readonly property real startX: {
                        field.cursorRectangle;
                        return field.positionToRectangle(modelData.start).x;
                    }
                    readonly property real endX: {
                        field.cursorRectangle;
                        return field.positionToRectangle(modelData.end).x;
                    }

                    x: startX - 2
                    width: endX - startX + 4
                    height: 22
                    anchors.verticalCenter: parent.verticalCenter
                    radius: 4
                    color: Theme.alpha(field.tokenColor(modelData), 0.25)
                }
            }
        }
    }

    BarText {
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F0415}"
        color: Theme.foregroundMuted
        font.pixelSize: 16
    }
}
