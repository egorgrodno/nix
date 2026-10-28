import QtQuick

// The user's words that the desk answered a decision on.
SelectableText {
    property string words

    wrapMode: TextEdit.Wrap
    color: Theme.foregroundMuted
    font.pixelSize: 14
    text: `You said: “${words}”`
}
