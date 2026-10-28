import QtQuick
import Quickshell

// Under the module, or over it on a bar along the bottom edge, centred on it
// unless that would cross the outer gap, as a panel is, after half a second's
// hover. It slides out from the module's side as it fades in, and back once the
// pointer leaves, clipped at the window's edge: a window reaching over the
// module would take the hover off it.
PopupWindow {
    id: tip

    required property Item target
    property string text
    // Built in place of the text.
    property Component content: null
    property bool hovered
    // To the target's right, centred on it, sliding out from it, as for a
    // rail's tile.
    property bool beside: false
    // The target's x in its window, read when the tooltip opens.
    property real targetX
    // False from the start of the fade out.
    property bool shown: false
    readonly property bool upward: {
        const anchors = target.QsWindow.window?.anchors;
        return anchors?.bottom === true && anchors?.top !== true;
    }

    // Hides it until the pointer leaves and comes back, as a click does in GTK.
    function dismiss() {
        delay.stop();
        shown = false;
        visible = false;
    }

    anchor.item: target
    anchor.rect.x: beside ? target.width + 4 : Math.max(Theme.outerGap, Math.min(targetX + (target.width - implicitWidth) / 2, (target.QsWindow.window?.width ?? 0) - Theme.outerGap - implicitWidth)) - targetX
    anchor.rect.y: beside ? 0 : upward ? -4 : 0
    anchor.rect.width: beside ? 1 : implicitWidth
    anchor.rect.height: beside ? target.height : upward ? 1 : target.height + 4
    anchor.edges: beside ? Edges.Right : upward ? Edges.Top : Edges.Bottom
    anchor.gravity: beside ? Edges.Right : upward ? Edges.Top : Edges.Bottom
    anchor.adjustment: beside ? PopupAdjustment.SlideY : PopupAdjustment.SlideX
    implicitWidth: box.implicitWidth
    implicitHeight: box.implicitHeight
    color: "transparent"
    visible: false

    onHoveredChanged: {
        if (hovered) {
            delay.interval = Tooltips.browsing ? 60 : 500;
            delay.restart();
        } else {
            delay.stop();
            if (shown) {
                shown = false;
                Tooltips.left();
            }
        }
    }

    onTextChanged: if (text === "" && !content)
        dismiss()

    Timer {
        id: delay

        onTriggered: {
            if (tip.text === "" && !tip.content)
                return;
            tip.targetX = tip.target.mapToItem(null, 0, 0).x;
            tip.visible = true;
            tip.shown = true;
            Tooltips.shown();
        }
    }

    Rectangle {
        id: box

        implicitWidth: (body.item?.implicitWidth ?? label.implicitWidth) + 2 * 16
        implicitHeight: (body.item?.implicitHeight ?? label.implicitHeight) + 2 * 12
        color: Theme.alpha(Theme.backgroundRaised, 0.97)
        border.color: Theme.tint(0.08)
        border.width: 1
        radius: Theme.radius
        x: tip.shown || !tip.beside ? 0 : -Theme.slide
        y: tip.shown || tip.beside ? 0 : tip.upward ? Theme.slide : -Theme.slide
        opacity: tip.shown ? 1 : 0
        onOpacityChanged: if (!tip.shown && opacity === 0)
            tip.visible = false

        // One curve both ways, as in Panel.qml.
        Behavior on x {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutExpo
            }
        }

        Behavior on y {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutExpo
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutExpo
            }
        }

        BarText {
            id: label

            anchors.centerIn: parent
            visible: !body.item
            text: tip.text
            lineHeight: 24
            lineHeightMode: Text.FixedHeight
        }

        Loader {
            id: body

            anchors.centerIn: parent
            // Built from the hover on, so a target that never shows its tip
            // keeps none.
            active: delay.running || tip.visible
            sourceComponent: tip.content
        }
    }
}
