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

    // The text's padding, which `copied` leaves out, as a flat list of each
    // run's start and end.
    function pads() {
        return [];
    }

    // Selects from `anchor` to `cursor`, but never ends a selection inside
    // a padding, which would highlight what copy leaves out.
    function choose(anchor, cursor) {
        let from = Math.min(anchor, cursor);
        let to = Math.max(anchor, cursor);
        const runs = held;
        for (let i = 0; i < runs.length; i += 2) {
            if (from >= runs[i] && from < runs[i + 1])
                from = runs[i + 1];
            if (to > runs[i] && to <= runs[i + 1])
                to = runs[i];
        }
        if (from >= to)
            twin.item.cursorPosition = anchor;
        else if (anchor < cursor)
            twin.item.select(from, to);
        else
            twin.item.select(to, from);
    }

    // A press at (x, y) starts a selection there and clears any elsewhere.
    function press(x, y) {
        MouseSelection.take(root);
        twin.active = true;
        if (held === null)
            held = pads();
        anchor = twin.item.positionAt(x, y);
        twin.item.cursorPosition = anchor;
    }

    // A drag to (x, y) takes the selection there.
    function drag(x, y) {
        choose(anchor, twin.item.positionAt(x, y));
    }

    function pickWord(x, y) {
        press(x, y);
        twin.item.selectWord();
        choose(twin.item.selectionStart, twin.item.selectionEnd);
    }

    // Selects the line under (x, y) up to its break, which leaves a wrapped
    // paragraph whole. Rich text's plain text breaks lines with U+2028 and
    // blocks with U+2029, and marks a table cell's start with U+FDD0 and a
    // table's end with U+FDD1.
    function pickLine(x, y) {
        press(x, y);
        const plain = getText(0, length);
        const breaks = "\n\u2028\u2029\ufdd0\ufdd1";
        let from = anchor;
        while (from > 0 && !breaks.includes(plain[from - 1]))
            from--;
        let to = anchor;
        while (to < plain.length && !breaks.includes(plain[to]))
            to++;
        choose(from, to);
    }

    // Where the press that started the selection fell.
    property int anchor: 0
    // `pads`, kept from the first press until the text changes.
    property var held: null

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
    onTextChanged: held = null
    Component.onDestruction: MouseSelection.drop(root)

    // Drives the twin's selection, as the TextEdit's own `selectByMouse`
    // would the text's.
    MouseArea {
        id: mouse

        // The link under the pointer, or "".
        property string link: ""
        // When and where the last double click fell: MouseArea has no triple
        // click, so a press soon after and close by is one.
        property real doubled: 0
        property point doubledAt
        // Whether this press picked a line, which a drag would undo.
        property bool lined: false

        z: 1
        anchors.fill: parent
        hoverEnabled: true
        // A list or flickable behind the text takes a drag past its threshold
        // otherwise, and the selection stops growing.
        preventStealing: true
        cursorShape: link !== "" ? Qt.PointingHandCursor : Qt.IBeamCursor
        onPressed: event => {
            lined = Date.now() - doubled < Qt.styleHints.mouseDoubleClickInterval && Math.abs(event.x - doubledAt.x) + Math.abs(event.y - doubledAt.y) < Qt.styleHints.startDragDistance;
            if (lined) {
                doubled = 0;
                root.pickLine(event.x, event.y);
            } else
                root.press(event.x, event.y);
        }
        onPositionChanged: event => {
            if (!pressed)
                link = root.linkAt(event.x, event.y);
            else if (!lined)
                root.drag(event.x, event.y);
        }
        onClicked: event => {
            const target = root.linkAt(event.x, event.y);
            if (target !== "" && root.chosen() === "")
                root.linkActivated(target);
        }
        onDoubleClicked: event => {
            doubled = Date.now();
            doubledAt = Qt.point(event.x, event.y);
            root.pickWord(event.x, event.y);
        }
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
        }
    }
}
