import QtQuick
import QtQuick.Controls.Basic

// The scroll bar of every view that scrolls, attached as ScrollBar.vertical or
// ScrollBar.horizontal. It floats over the view's edge (right, or bottom when
// horizontal) and never narrows the content. Hidden at rest, it fades in while
// the view scrolls or the pointer is over its track, widens under the pointer
// or a drag, and lingers a second after either ends.
ScrollBar {
    id: bar

    // Set by a move or a pointer event, cleared once the linger runs out.
    property bool recent: false
    readonly property bool shown: size < 1 && (hovered || pressed || recent)

    // The track is wider than the thumb so the thumb is easy to hit.
    implicitWidth: 14
    implicitHeight: 14
    padding: 0
    policy: ScrollBar.AlwaysOn
    visible: size < 1
    hoverEnabled: true
    // A long view would shrink the thumb past grabbing; its travel shrinks
    // with it.
    minimumSize: {
        const length = vertical ? height : width;
        return length > 0 ? Math.min(1, 36 / length) : 0;
    }
    // Content growth and a view positioning itself change the position too,
    // and must not show the bar; only the user's scroll does. A view that
    // scrolls without the Flickable's own wheel or drag calls poke().
    onPositionChanged: if (pressed || (parent?.moving ?? false))
        poke()
    onHoveredChanged: poke()
    onPressedChanged: poke()

    function poke() {
        recent = true;
        linger.restart();
    }

    Timer {
        id: linger

        interval: 1000
        onTriggered: bar.recent = false
    }

    // The mouse scrolls the view with the wheel or this bar, never by a drag,
    // which would flick it from a gap between blocks where the user meant to
    // select text. `interactive: false` would stop the wheel too.
    Binding {
        when: bar.parent?.acceptedButtons !== undefined
        target: bar.parent
        property: "acceptedButtons"
        value: Qt.NoButton
    }

    contentItem: Item {
        opacity: bar.shown ? 1 : 0

        // The thumb's own span, not the track around it.
        HoverHandler {
            id: overThumb
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 180
                easing.type: Easing.OutCubic
            }
        }

        Rectangle {
            id: thumb

            property real thickness: bar.hovered || bar.pressed ? 8 : 4

            x: bar.vertical ? parent.width - width - 2 : 0
            y: bar.vertical ? 0 : parent.height - height - 2
            width: bar.vertical ? thickness : parent.width
            height: bar.vertical ? parent.height : thickness
            radius: thickness / 2
            color: overThumb.hovered || bar.pressed ? Theme.tint(0.5) : Theme.tint(0.25)

            Behavior on color {
                ColorAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on thickness {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
