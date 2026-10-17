import QtQuick
import Quickshell

// A GTK tooltip as Waybar styles it: under the module, centred on where the
// pointer came to rest, after half a second's hover.
PopupWindow {
    id: tip

    required property Item target
    property string text
    property bool hovered
    // Pointer x in the target, read when the tooltip opens.
    property real pointerX
    property real openedAt

    // Hides it until the pointer leaves and comes back, as a click does in GTK.
    function dismiss() {
        delay.stop();
        visible = false;
    }

    anchor.item: target
    anchor.rect.x: openedAt
    anchor.rect.width: 1
    anchor.rect.height: target.height + 4
    anchor.edges: Edges.Bottom
    anchor.gravity: Edges.Bottom
    anchor.adjustment: PopupAdjustment.SlideX
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
            if (visible) {
                visible = false;
                Tooltips.left();
            }
        }
    }

    onTextChanged: if (text === "")
        dismiss()

    Timer {
        id: delay

        onTriggered: {
            if (tip.text === "")
                return;
            tip.openedAt = tip.pointerX;
            tip.visible = true;
            Tooltips.shown();
        }
    }

    Rectangle {
        id: box

        // Border, the GTK theme's padding and Waybar's label padding, summed.
        implicitWidth: label.implicitWidth + 2 * 16
        implicitHeight: label.implicitHeight + 2 * 12
        color: Theme.backgroundMain
        border.color: Theme.blue
        border.width: 2
        radius: Theme.radius
        opacity: 0.95

        BarText {
            id: label

            anchors.centerIn: parent
            text: tip.text
            lineHeight: 25
            lineHeightMode: Text.FixedHeight
        }
    }
}
