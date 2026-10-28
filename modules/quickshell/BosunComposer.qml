import QtQuick

// The panel's text field: text that grows to a few lines and then scrolls, and
// a glyph that sends it, as Ctrl+Enter does, then clears. Enter starts a line.
// Tab and Escape leave it, for the panel to say where to. A suggested reply
// stands in for the placeholder while the field is empty, and Tab fills the
// field with it. `oneLine` makes it a single line that Return submits.
Rectangle {
    id: field

    property string placeholder
    property string suggestion: ""
    readonly property bool suggesting: suggestion !== "" && input.text === ""
    // A single line, centred in whatever height the caller gave, which Return
    // submits as Ctrl+Enter does.
    property bool oneLine: false
    // Submitting sends the text and clears it. Off, it only emits `accepted`.
    property bool sends: true
    // A glyph that sends, which a single line goes without unless it asks.
    property bool sendGlyph: sends && !oneLine
    // A muted glyph in front of the text.
    property string leadGlyph
    // The field Tab moves to, where Tab would otherwise leave.
    property Item next: null
    property alias text: input.text
    readonly property bool focused: input.activeFocus
    readonly property int cursor: input.cursorPosition
    // A field that grows is as tall as its text, from `minHeight` up to this
    // many lines, and scrolls past it.
    property real minHeight: 40
    property int maxLines: 6
    // What BosunKept keeps the text under until it is sent, or "" to keep
    // none. A field that serves many keys shows each one's own.
    property string draftKey: ""

    signal sent(string text)
    signal accepted
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

    function submit() {
        if (sends)
            send();
        else
            accepted();
    }

    // Fills an empty field with the suggestion showing, else moves on.
    function tab() {
        if (suggesting) {
            input.text = suggestion;
            input.cursorPosition = input.length;
        } else if (next)
            next.focusIn();
        else
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

    height: Math.min(Math.max(minHeight, input.implicitHeight), maxLines * metrics.lineSpacing + 20)
    radius: Theme.radius - 4
    color: Theme.tint(0.06)
    border.color: input.activeFocus ? Theme.blue : Theme.tint(0.12)
    border.width: 1

    FontMetrics {
        id: metrics

        font: input.font
    }

    BarText {
        id: lead

        x: 10
        anchors.verticalCenter: parent.verticalCenter
        visible: field.leadGlyph !== ""
        text: field.leadGlyph
        color: Theme.foregroundMuted
        font.pixelSize: 14
    }

    Flickable {
        id: scroller

        anchors.left: lead.visible ? lead.right : parent.left
        anchors.leftMargin: lead.visible ? 8 : 12
        anchors.right: field.sendGlyph ? sendButton.left : parent.right
        anchors.rightMargin: field.sendGlyph ? 8 : 12
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        clip: true
        contentWidth: input.width
        contentHeight: input.height
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height || contentWidth > width
        // No drag to scroll, as OverlayScrollBar gives the other views.
        acceptedButtons: Qt.NoButton

        TextEdit {
            id: input

            // A line that does not wrap scrolls sideways instead.
            width: field.oneLine ? Math.max(scroller.width, implicitWidth + 2) : scroller.width
            topPadding: field.oneLine ? Math.max(0, (field.height - metrics.lineSpacing) / 2) : 10
            bottomPadding: topPadding
            wrapMode: field.oneLine ? TextEdit.NoWrap : TextEdit.Wrap
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
                if (!field.oneLine)
                    return;
                if (r.x < scroller.contentX)
                    scroller.contentX = r.x;
                else if (r.x + r.width > scroller.contentX + scroller.width)
                    scroller.contentX = r.x + r.width - scroller.width;
            }
            Keys.onPressed: event => {
                if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter)
                    return;
                if (event.modifiers & Qt.ControlModifier || field.oneLine) {
                    field.submit();
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
                width: scroller.width
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
        y: ((field.oneLine ? field.height : 40) - implicitHeight) / 2
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
