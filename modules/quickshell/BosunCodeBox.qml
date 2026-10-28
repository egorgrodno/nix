import QtQuick

// Text in a box on a tint, selectable, for a tool's input and result and a
// Markdown message's fenced code. A line breaks at a space where it can and
// anywhere else, as the prose around an inline code span does.
Rectangle {
    id: box

    property alias text: codeText.text
    property color tint: Theme.tint(0.06)
    property color textColor: Theme.foregroundStrong
    property bool mono: true
    property real padX: 12
    property real padY: 10
    // Shrinks to a short text, where it would fill the parent's width.
    property bool fit: false

    width: fit ? Math.min(parent?.width ?? 0, codeText.implicitWidth + 2 * padX) : parent?.width ?? 0
    height: codeText.implicitHeight + 2 * padY
    radius: 4
    color: tint

    SelectableText {
        id: codeText

        x: box.padX
        y: box.padY
        width: parent.width - 2 * x
        wrapMode: TextEdit.Wrap
        color: box.textColor
        font.family: box.mono ? Theme.fontMono : Theme.fontUI
        font.pixelSize: box.mono ? 13 : 14
    }
}
