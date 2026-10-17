import QtQuick
import Quickshell

// Under the module, or over it on a bar along the bottom edge, centred on where
// the pointer came to rest, after half a second's hover, as GTK places a
// tooltip.
PopupWindow {
    id: tip

    required property Item target
    property string text
    // Built in place of the text.
    property Component content: null
    property bool hovered
    // Pointer x in the target, read when the tooltip opens.
    property real pointerX
    property real openedAt
    readonly property bool upward: {
        const anchors = target.QsWindow.window?.anchors;
        return anchors?.bottom === true && anchors?.top !== true;
    }

    // Hides it until the pointer leaves and comes back, as a click does in GTK.
    function dismiss() {
        delay.stop();
        visible = false;
    }

    anchor.item: target
    anchor.rect.x: openedAt
    anchor.rect.y: upward ? -4 : 0
    anchor.rect.width: 1
    anchor.rect.height: upward ? 1 : target.height + 4
    anchor.edges: upward ? Edges.Top : Edges.Bottom
    anchor.gravity: upward ? Edges.Top : Edges.Bottom
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

    onTextChanged: if (text === "" && !content)
        dismiss()

    Timer {
        id: delay

        onTriggered: {
            if (tip.text === "" && !tip.content)
                return;
            tip.openedAt = tip.pointerX;
            tip.visible = true;
            Tooltips.shown();
        }
    }

    Rectangle {
        id: box

        implicitWidth: (body.item?.implicitWidth ?? label.implicitWidth) + 2 * 16
        implicitHeight: (body.item?.implicitHeight ?? label.implicitHeight) + 2 * 12
        color: Theme.alpha(Theme.backgroundMain, 0.97)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        radius: Theme.radius

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
            sourceComponent: tip.content
        }
    }
}
