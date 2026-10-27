import QtQuick

// BarText's look in a read-only TextEdit the mouse selects, for
// MouseSelection to copy. It never takes the keyboard, so the panel's keys act
// on while text is selected. Unlike a Text, it keeps each press from what
// lies under it.
//
// A change to the scene graph's nodes makes Qt prepare every curve glyph in
// view again, tens of milliseconds a step of a drag, and a TextEdit rebuilds
// its nodes on every selection change. So the selection lives in a twin
// beneath the text, drawn in a layer of its own: distance-field and
// transparent, it lays out as the text does and draws only the highlight,
// while the curve text above never changes. The twin lasts from the first
// press to the next selection elsewhere, as most rows never see one.
TextEdit {
    id: root

    // What `copied` reads, as the twin's own text selects it.
    function chosen() {
        return twin.item?.selectedText ?? "";
    }

    // The selection's start and end in the text, which is `[0, 0]` with none.
    function chosenRange() {
        return twin.item ? [twin.item.selectionStart, twin.item.selectionEnd] : [0, 0];
    }

    // The selection as plain text, as it reads.
    function copied() {
        return chosen().replace(/[\u2028\u2029]/g, "\n").replace(/\u00a0/g, " ");
    }

    function clearSelection() {
        twin.active = false;
    }

    // A press at (x, y) starts a selection there.
    function press(x, y) {
        twin.active = true;
        twin.item.cursorPosition = twin.item.positionAt(x, y);
    }

    // A drag to (x, y) takes the selection there.
    function drag(x, y) {
        twin.item.moveCursorSelection(twin.item.positionAt(x, y));
    }

    function pickWord(x, y) {
        press(x, y);
        twin.item.selectWord();
    }

    // What the selection is mixed against: the panel body, which most text
    // sits on. Code blocks and table rows lift it by a few percent at most.
    property color selectionBase: Theme.backgroundRaised
    // What the twin lays out: the text as set. A rich text reads back from
    // `text` as Qt's own HTML, which lays out differently, so one sets this too.
    property string origin: text

    color: Theme.foregroundStrong
    font.family: Theme.fontUI
    font.pixelSize: 16
    font.hintingPreference: Font.PreferFullHinting
    renderType: TextEdit.CurveRendering
    textFormat: TextEdit.PlainText
    readOnly: true
    Component.onDestruction: MouseSelection.drop(root)

    // Drives the twin's selection, as the TextEdit's own `selectByMouse`
    // would the text's.
    MouseArea {
        id: mouse

        // The link under the pointer, or "".
        property string link: ""

        z: 1
        anchors.fill: parent
        hoverEnabled: true
        // A list or flickable behind the text takes a drag past its threshold
        // otherwise, and the selection stops growing.
        preventStealing: true
        cursorShape: link !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor
        onPressed: event => root.press(event.x, event.y)
        onPositionChanged: event => {
            if (pressed)
                root.drag(event.x, event.y);
            else
                link = root.linkAt(event.x, event.y);
        }
        onClicked: event => {
            const target = root.linkAt(event.x, event.y);
            if (target !== "" && root.chosen() === "")
                root.linkActivated(target);
        }
        onDoubleClicked: event => root.pickWord(event.x, event.y)
    }

    Loader {
        id: twin

        // Between the code boxes and table bands at -1 and the text at 0.
        z: -0.5
        active: false

        sourceComponent: TextEdit {
            width: root.width
            text: root.origin
            textFormat: root.textFormat
            wrapMode: root.wrapMode
            font: root.font
            color: "transparent"
            // A texture taller than a GPU holds draws nothing, so a text
            // that tall keeps its highlight in the scene.
            layer.enabled: height * Screen.devicePixelRatio < 16000
            readOnly: true
            activeFocusOnPress: false
            persistentSelection: true
            renderType: TextEdit.QtRendering
            // Opaque, since Qt's rectangle for each line overlaps the next by
            // a pixel and a translucent colour shows that as a darker band.
            selectionColor: Qt.tint(root.selectionBase, Theme.alpha(Theme.blue, 0.35))
            selectedTextColor: "transparent"
            onSelectionEndChanged: if (selectionEnd > selectionStart)
                MouseSelection.take(root)
        }
    }
}
