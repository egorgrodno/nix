import QtQuick
import Quickshell

// Under the module, or over it on a bar along the bottom edge, centred on it,
// after half a second's hover. It slides out from the module's side as it fades
// in, and back once the pointer leaves, clipped at the window's edge: a window
// reaching over the module would take the hover off it.
PopupWindow {
    id: tip

    required property Item target
    property string text
    // Built in place of the text.
    property Component content: null
    property bool hovered
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
    anchor.rect.y: upward ? -4 : 0
    anchor.rect.width: target.width
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
        y: tip.shown ? 0 : tip.upward ? Theme.slide : -Theme.slide
        opacity: tip.shown ? 1 : 0
        onOpacityChanged: if (!tip.shown && opacity === 0)
            tip.visible = false

        // One curve both ways, as in Panel.qml.
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
            sourceComponent: tip.content
        }
    }
}
