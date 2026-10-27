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

    color: Theme.foregroundStrong
    font.family: Theme.fontUI
    font.pixelSize: 16
    font.hintingPreference: Font.PreferFullHinting
    renderType: TextEdit.CurveRendering
    textFormat: TextEdit.PlainText
    readOnly: true
    selectByMouse: true
    activeFocusOnPress: false
    selectionColor: Theme.alpha(Theme.blue, 0.35)
    selectedTextColor: color
    onSelectedTextChanged: if (selectedText !== "")
        MouseSelection.take(text)
    Component.onDestruction: MouseSelection.drop(text)
}
