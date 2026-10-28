import QtQuick

// A session state's glyph, or another glyph, a number and, unless it is
// empty, a word, centred on its parent's height, as in a Row of them.
Row {
    id: count

    // A key of BosunLook.states, whose glyph and colour it shows.
    property string stateKey
    // A glyph in the state's place, muted.
    property string glyph
    property int n
    property string word
    property int pixelSize: 14

    y: ((parent?.height ?? height) - height) / 2
    spacing: 6

    BosunStateGlyph {
        anchors.verticalCenter: parent.verticalCenter
        stateKey: count.stateKey
        text: count.glyph !== "" ? count.glyph : BosunLook.states[count.stateKey]?.glyph ?? ""
        font.pixelSize: count.pixelSize
    }

    BarText {
        anchors.verticalCenter: parent.verticalCenter
        text: `${count.n}`
        color: count.word === "" ? Theme.foregroundMuted : Theme.foregroundStrong
        font.pixelSize: count.pixelSize
    }

    BarText {
        anchors.verticalCenter: parent.verticalCenter
        visible: count.word !== ""
        text: count.word
        color: Theme.foregroundMuted
        font.pixelSize: count.pixelSize
    }
}
