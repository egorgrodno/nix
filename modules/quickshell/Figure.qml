import QtQuick

// A figure in the mono face, in a slot as wide as `widest`, so a changing value
// never moves its neighbours.
BarText {
    id: figure

    property string widest

    width: Math.max(implicitWidth, metrics.advanceWidth)
    font.family: Theme.fontMono
    font.pixelSize: 16

    TextMetrics {
        id: metrics

        font: figure.font
        text: figure.widest
    }
}
