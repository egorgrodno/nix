import QtQuick

// A line on a tint of its colour, under a glyph: a note in a pane, or with
// `strip` a band across the panel. It takes its parent's width.
Rectangle {
    id: banner

    property string glyph
    property color tint
    // What the fill tints, when it is not the text's colour.
    property color fill: tint
    property string text
    // Square-cornered and set further in, for a band the panel's edges bound.
    property bool strip: false
    readonly property real inset: strip ? 20 : 12

    width: parent?.width ?? 0
    height: bannerText.implicitHeight + 20
    radius: strip ? 0 : Theme.radius - 4
    color: Theme.alpha(fill, 0.12)

    BarText {
        id: bannerGlyph

        x: banner.inset
        y: 10
        text: banner.glyph
        color: banner.tint
        font.pixelSize: 14
    }

    BarText {
        id: bannerText

        anchors.left: bannerGlyph.right
        anchors.leftMargin: 10
        y: 10
        width: parent.width - x - banner.inset
        wrapMode: Text.Wrap
        text: banner.text
        color: banner.tint
        font.pixelSize: 14
    }
}
