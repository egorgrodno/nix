import QtQuick

// A conversation's card: a rounded box on a tint, with an optional header of
// a caption on the left and the age on the right. What the caller declares
// inside it stacks below the header. It takes its parent's width unless given
// one, and its height from its content.
Rectangle {
    id: card

    property string caption
    property color captionColor: Theme.foregroundMuted
    property string age
    // The user's own message, on blue instead of grey.
    property bool mine: false
    // Outlined instead of filled, for a message not yet taken.
    property bool outlined: false
    property real spacing: 6
    property real inset: 12
    property real insetY: inset
    default property alias content: body.data

    height: body.implicitHeight + 2 * insetY
    radius: Theme.radius - 4
    color: outlined ? "transparent" : mine ? Theme.alpha(Theme.blue, 0.16) : Theme.tint(0.05)
    border.width: outlined ? 1 : 0
    border.color: Theme.tint(0.12)

    Column {
        id: body

        x: card.inset
        y: card.insetY
        width: parent.width - 2 * card.inset
        spacing: card.spacing

        Item {
            width: parent.width
            height: captionText.implicitHeight
            visible: card.caption !== ""

            Caption {
                id: captionText

                text: card.caption
                color: card.captionColor
            }

            Caption {
                anchors.right: parent.right
                text: card.age
            }
        }
    }
}
