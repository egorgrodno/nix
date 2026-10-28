import QtQuick

// A session state's glyph in its colour, or for "working" the spinner in the
// glyph's box, which keeps its neighbours where they are. Not hidden by
// opacity, which the spinner would inherit.
BarText {
    id: glyph

    // A key of BosunLook.states.
    property string stateKey
    // The glyph's and the spinner's colour, its state's unless set.
    property color tint: BosunLook.stateColor(stateKey)

    text: BosunLook.states[stateKey]?.glyph ?? ""
    color: stateKey === "working" ? "transparent" : tint

    BosunSpinner {
        anchors.centerIn: parent
        visible: glyph.stateKey === "working"
        color: glyph.tint
        size: glyph.font.pixelSize - 2
    }
}
