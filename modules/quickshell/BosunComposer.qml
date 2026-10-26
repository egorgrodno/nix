import QtQuick

// A line of text and a glyph that sends it, as Return does, then clears. Tab
// and Escape leave it, for the panel to say where to.
Rectangle {
    id: field

    property string placeholder
    // Off for a field that Return alone sends, as the note Deny takes.
    property bool sendGlyph: true
    property alias text: input.text
    readonly property bool focused: input.activeFocus
    // What BosunKept keeps the text under until it is sent, or "" to keep
    // none. A field that serves many keys shows each one's own.
    property string draftKey: ""

    signal sent(string text)
    signal leave

    onDraftKeyChanged: if (draftKey !== "")
        input.text = BosunKept.draft(draftKey)
    onTextChanged: if (draftKey !== "")
        BosunKept.keepDraft(draftKey, input.text)
    Component.onCompleted: if (draftKey !== "")
        input.text = BosunKept.draft(draftKey)

    function send() {
        const text = input.text.trim();
        if (text === "")
            return;
        sent(text);
        input.text = "";
    }

    function focusIn() {
        input.forceActiveFocus();
    }

    height: 40
    radius: Theme.radius - 4
    color: Theme.tint(0.06)
    border.color: input.activeFocus ? Theme.blue : Theme.tint(0.12)
    border.width: 1

    TextInput {
        id: input

        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: field.sendGlyph ? sendButton.left : parent.right
        anchors.rightMargin: field.sendGlyph ? 8 : 12
        anchors.verticalCenter: parent.verticalCenter
        clip: true
        color: Theme.foregroundStrong
        selectionColor: Theme.blue
        selectByMouse: true
        font.family: Theme.fontUI
        font.pixelSize: 14
        font.hintingPreference: Font.PreferFullHinting
        renderType: Text.CurveRendering
        Keys.onReturnPressed: field.send()
        Keys.onEnterPressed: field.send()
        Keys.onTabPressed: field.leave()
        Keys.onEscapePressed: field.leave()

        BarText {
            anchors.verticalCenter: parent.verticalCenter
            visible: input.text === ""
            text: field.placeholder
            color: Theme.foregroundMuted
            font.pixelSize: 14
        }
    }

    BarText {
        id: sendButton

        visible: field.sendGlyph
        anchors.right: parent.right
        anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        text: BosunLook.send
        color: input.text !== "" && sendMouse.containsMouse ? Theme.foregroundStrong : Theme.foregroundMuted

        MouseArea {
            id: sendMouse

            anchors.fill: parent
            anchors.margins: -6
            hoverEnabled: true
            onClicked: field.send()
        }
    }
}
