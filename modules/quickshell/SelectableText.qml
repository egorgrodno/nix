import QtQuick

// BarText's look in a read-only TextEdit the mouse selects, for
// MouseSelection to copy. It never takes the keyboard, so the panel's keys act
// on while text is selected. Unlike a Text, it keeps each press from what
// lies under it.
TextEdit {
    id: text

    // The selection as plain text, as it reads.
    function copied() {
        return selectedText.replace(/[\u2028\u2029]/g, "\n").replace(/\u00a0/g, " ");
    }

    // What the selection is mixed against: the panel body, which most text
    // sits on. Code blocks and table rows lift it by a few percent at most.
    property color selectionBase: Theme.backgroundRaised

    color: Theme.foregroundStrong
    font.family: Theme.fontUI
    font.pixelSize: 16
    font.hintingPreference: Font.PreferFullHinting
    renderType: TextEdit.CurveRendering
    textFormat: TextEdit.PlainText
    readOnly: true
    selectByMouse: true
    activeFocusOnPress: false
    // Opaque, since Qt's rectangle for each line overlaps the next by a pixel
    // and a translucent colour shows that as a darker band.
    selectionColor: Qt.tint(selectionBase, Theme.alpha(Theme.blue, 0.35))
    selectedTextColor: color
    onSelectedTextChanged: if (selectedText !== "")
        MouseSelection.take(text)
    Component.onDestruction: MouseSelection.drop(text)
}
