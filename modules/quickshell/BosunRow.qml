import QtQuick

// A row of a list that selects: filled while it is `current`, filled less
// under the pointer, with a 2 px edge at its left that is blue while the
// keyboard is in the list. A tap emits `tapped`; what the row holds is the
// caller's. An `inert` row, an entry with nothing behind it, takes no hover
// fill or tap, though `hovered` still reports the pointer for a tooltip.
Item {
    id: row

    property bool current: false
    // Filled without being current, as a button that stays on.
    property bool lit: current
    // The keyboard is in the list.
    property bool focused: false
    // The margin either side of the fill, and how far left of the fill the
    // edge sits.
    property real inset: 0
    property real edgeOffset: 0
    // The fill eases between states, which a long list does not need.
    property bool fades: false
    property bool inert: false
    readonly property bool hovered: hover.hovered

    signal tapped

    Rectangle {
        anchors.fill: parent
        anchors.leftMargin: row.inset
        anchors.rightMargin: row.inset
        radius: Theme.radius - 4
        color: row.lit ? Theme.tint(0.12) : row.hovered && !row.inert ? Theme.tint(0.08) : "transparent"

        Rectangle {
            x: row.edgeOffset
            width: 2
            height: parent.height
            visible: row.current
            color: row.focused ? Theme.blue : Theme.foregroundFaint
        }

        Behavior on color {
            enabled: row.fades

            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }
    }

    HoverHandler {
        id: hover
    }

    TapHandler {
        enabled: !row.inert
        onTapped: row.tapped()
    }
}
