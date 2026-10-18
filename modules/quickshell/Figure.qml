import QtQuick

// A figure in the mono face, in a slot as wide as `widest`, so a changing value
// never moves its neighbours.
BarText {
    id: figure

    property string widest

    width: Math.max(implicitWidth, metrics.advanceWidth)
    font.family: Theme.fontMono
    font.pixelSize: 16
    // Centred on its digits rather than its line, whose descent would sit them
    // below the glyphs beside them.
    anchors.verticalCenterOffset: Math.round(implicitHeight / 2 - baselineOffset - digit.tightBoundingRect.y - digit.tightBoundingRect.height / 2)

    TextMetrics {
        id: metrics

        font: figure.font
        text: figure.widest
    }

    TextMetrics {
        id: digit

        font: figure.font
        text: "0"
    }
}
