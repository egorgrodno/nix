import QtQuick

// Why the master passed a decision on to the user, on a blue card. It may say
// the decision needs no answer.
Rectangle {
    id: card

    property string text

    width: parent?.width ?? 0
    height: column.implicitHeight + 24
    radius: Theme.radius - 4
    color: Theme.alpha(Theme.blue, 0.12)
    border.width: 1
    border.color: Theme.alpha(Theme.blue, 0.4)

    Column {
        id: column

        x: 12
        y: 12
        width: parent.width - 2 * x
        spacing: 6

        BosunFact {
            glyph: BosunLook.master
            glyphColor: Theme.blue
            text: "Why the master passed it to you"
        }

        SelectableText {
            width: parent.width
            wrapMode: TextEdit.Wrap
            font.pixelSize: 16
            text: card.text
        }
    }
}
