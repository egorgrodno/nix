import QtQuick
import QtQuick.Controls.Basic

// The scroll bar of every bosun view that scrolls. It floats over the view's
// right edge and never narrows the content. Hidden at rest, it fades in while
// the view scrolls or the pointer is over its track, widens under the pointer
// or a drag, and lingers a second after either ends.
ScrollBar {
    id: bar

    // Set by a move or a pointer event, cleared once the linger runs out.
    property bool recent: false
    readonly property bool shown: size < 1 && (hovered || pressed || recent)

    // The track is wider than the thumb so the thumb is easy to hit.
    implicitWidth: 14
    padding: 0
    policy: ScrollBar.AlwaysOn
    visible: size < 1
    hoverEnabled: true
    // A long view would shrink the thumb past grabbing; its travel shrinks
    // with it.
    minimumSize: height > 0 ? Math.min(1, 36 / height) : 0
    onPositionChanged: poke()
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

            anchors.top: parent.top
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.rightMargin: 2
            width: bar.hovered || bar.pressed ? 8 : 4
            radius: width / 2
            color: overThumb.hovered || bar.pressed ? Theme.tint(0.5) : Theme.tint(0.25)

            Behavior on color {
                ColorAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on width {
                NumberAnimation {
                    duration: 150
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
