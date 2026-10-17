import QtQuick

// A right-hand module: text, or items placed in it, on a rounded fill, with an
// optional tooltip.
Rectangle {
    id: pill

    default property alias content: row.data
    property alias text: label.text
    property alias textColor: label.color
    property string tooltip
    // Waybar lights the fill on hover only for modules that act on a click.
    property bool hoverable: true
    property color fill: Theme.alpha(Theme.backgroundLight, 0.8)
    property color hoverFill: Theme.backgroundLight
    property int leftPadding: 16
    property int rightPadding: 16
    property bool roundLeft: true
    property bool roundRight: true
    readonly property bool hovered: hover.hovered

    signal clicked(int button)
    // One per wheel notch: positive up, negative down.
    signal scrolled(int steps)

    implicitWidth: leftPadding + row.implicitWidth + rightPadding
    height: parent.height
    topLeftRadius: roundLeft ? height / 2 : 0
    bottomLeftRadius: roundLeft ? height / 2 : 0
    topRightRadius: roundRight ? height / 2 : 0
    bottomRightRadius: roundRight ? height / 2 : 0
    color: hoverable && hovered ? hoverFill : fill

    Behavior on color {
        ColorAnimation {
            duration: 150
            easing.type: Easing.OutQuad
        }
    }

    HoverHandler {
        id: hover
    }

    // Under the content, so items placed in the pill take their own clicks.
    MouseArea {
        id: mouse

        property int wheel: 0

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        onPressed: tip.dismiss()
        onClicked: event => pill.clicked(event.button)
        onWheel: event => {
            wheel += event.angleDelta.y;
            const steps = Math.trunc(wheel / 120);
            if (steps !== 0) {
                wheel -= steps * 120;
                pill.scrolled(steps);
            }
        }
    }

    Row {
        id: row

        x: pill.leftPadding
        height: parent.height
        spacing: 10

        BarText {
            id: label

            anchors.verticalCenter: parent.verticalCenter
            visible: text !== ""
        }
    }

    Tooltip {
        id: tip

        target: pill
        text: pill.tooltip
        hovered: mouse.containsMouse
        pointerX: mouse.mouseX
    }
}
