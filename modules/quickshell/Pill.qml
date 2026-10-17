import QtQuick

// A right-hand module: text, or items placed in it, with an optional tooltip.
Item {
    id: pill

    default property alias content: row.data
    property alias text: label.text
    property alias textColor: label.color
    property string tooltip
    // Built in the tooltip in place of the text.
    property Component tooltipContent: null
    // Lit on hover only where a click acts on the module.
    property bool hoverable: true
    // Lit regardless, as while its popup is open.
    property bool lit: false
    property color hoverFill: Qt.rgba(1, 1, 1, 0.07)
    property int leftPadding: 12
    property int rightPadding: 12
    readonly property bool hovered: hover.hovered

    signal clicked(int button)
    // One per wheel notch: positive up, negative down.
    signal scrolled(int steps)

    implicitWidth: leftPadding + row.implicitWidth + rightPadding
    height: parent.height

    // Inset, and rounded concentric with the segment around it.
    Rectangle {
        anchors.fill: parent
        anchors.margins: 4
        radius: Theme.radius - 4
        color: pill.lit || pill.hoverable && pill.hovered ? pill.hoverFill : "transparent"

        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
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
        spacing: 8

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
        content: pill.tooltipContent
        hovered: mouse.containsMouse
        pointerX: mouse.mouseX
    }
}
