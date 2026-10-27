import QtQuick

// Text that grows to a few lines and then scrolls, and a glyph that sends it,
// as Ctrl+Enter does, then clears. Enter starts a line. Tab and Escape leave
// it, for the panel to say where to. A suggested reply stands in for the
// placeholder while the field is empty, and Tab fills the field with it.
Rectangle {
    id: field

    property string placeholder
    property string suggestion: ""
    readonly property bool suggesting: suggestion !== "" && input.text === ""
    // Off for a single line that Return alone sends, as the note Deny takes,
    // whose caller sets the height.
    property bool sendGlyph: true
    property alias text: input.text
    readonly property bool focused: input.activeFocus
    readonly property int cursor: input.cursorPosition
    readonly property int maxLines: 6
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

    // Fills an empty field with the suggestion showing, else leaves.
    function tab() {
        if (suggesting) {
            input.text = suggestion;
            input.cursorPosition = input.length;
        } else
            leave();
    }

    function focusIn() {
        input.forceActiveFocus();
    }

    // Takes the keyboard back, with its cursor, if it had it when the panel
    // closed. Once the open animation has ended, and the grab with it: until
    // then Hyprland may hand the keyboard to the window underneath.
    function refocus() {
        const kept = BosunKept.typing;
        if (!Bosun.panelEntered || !visible || draftKey === "" || kept?.key !== draftKey)
            return;
        BosunKept.typing = null;
        input.forceActiveFocus();
        input.cursorPosition = kept.cursor;
    }

    Connections {
        target: Bosun

        function onPanelEnteredChanged() {
            field.refocus();
        }
    }

    height: sendGlyph ? Math.min(Math.max(40, input.implicitHeight), maxLines * metrics.lineSpacing + 20) : 40
    radius: Theme.radius - 4
    color: Theme.tint(0.06)
    border.color: input.activeFocus ? Theme.blue : Theme.tint(0.12)
    border.width: 1

    FontMetrics {
        id: metrics

        font: input.font
    }

    Flickable {
        id: scroller

        anchors.left: parent.left
        anchors.leftMargin: 12
        anchors.right: field.sendGlyph ? sendButton.left : parent.right
        anchors.rightMargin: field.sendGlyph ? 8 : 12
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true
        contentWidth: width
        contentHeight: input.height
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        // No drag to scroll, as OverlayScrollBar gives the other views.
        acceptedButtons: Qt.NoButton

        TextEdit {
            id: input

            width: scroller.width
            // Centres a single line in whatever height the caller gave.
            topPadding: field.sendGlyph ? 10 : Math.max(0, (field.height - metrics.lineSpacing) / 2)
            bottomPadding: topPadding
            wrapMode: TextEdit.Wrap
            color: Theme.foregroundStrong
            selectionColor: Theme.blue
            selectByMouse: true
            font.family: Theme.fontUI
            font.pixelSize: 14
            font.hintingPreference: Font.PreferFullHinting
            renderType: Text.CurveRendering
            onCursorRectangleChanged: {
                const r = cursorRectangle;
                if (r.y < scroller.contentY)
                    scroller.contentY = r.y;
                else if (r.y + r.height > scroller.contentY + scroller.height)
                    scroller.contentY = r.y + r.height - scroller.height;
            }
            Keys.onPressed: event => {
                if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
                    return;
                if (event.modifiers & Qt.ControlModifier || !field.sendGlyph) {
                    field.send();
                    event.accepted = true;
                }
            }
            Keys.onTabPressed: field.tab()
            Keys.onEscapePressed: field.leave()

            BarText {
                y: input.topPadding
                visible: input.text === ""
                text: field.suggesting ? field.suggestion : field.placeholder
                color: Theme.foregroundMuted
                opacity: field.suggesting ? 0.6 : 1
                width: input.width
                wrapMode: Text.Wrap
                font.pixelSize: 14
            }
        }
    }

    BarText {
        id: sendButton

        visible: field.sendGlyph
        anchors.right: parent.right
        anchors.rightMargin: 12
        y: (40 - implicitHeight) / 2
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
