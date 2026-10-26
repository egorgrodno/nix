import QtQuick

// A fact in a header: its glyph, then its words.
Row {
    id: fact

    property string glyph
    property string text
    property color color: Theme.foregroundMuted
    property color glyphColor: color

    visible: text !== ""
    spacing: 6

    BarText {
        anchors.verticalCenter: parent.verticalCenter
        text: fact.glyph
        color: fact.glyphColor
        font.pixelSize: 14
    }

    BarText {
        anchors.verticalCenter: parent.verticalCenter
        text: fact.text
        color: fact.color
        font.pixelSize: 14
    }
}
