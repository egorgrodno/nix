import QtQuick
import QtQuick.Controls.Basic

// Todoist's Quick Add, which reads dates, #projects, @labels and p1 to p4 out
// of the text. A task it leaves without a date takes `day`, if any.
TextField {
    id: field

    // An ISO date, or "" for none.
    property string day: ""

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
    }

    BarText {
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F0415}"
        color: Theme.foregroundMuted
        font.pixelSize: 16
    }
}
