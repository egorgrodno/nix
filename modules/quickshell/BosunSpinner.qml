import QtQuick
import QtQuick.Shapes

// A running state's spinner: an arc of a circle that turns about the circle's
// centre. The arc is drawn, not a glyph, as a glyph's box is neither square
// nor centred on its mark. The square item turns about its own centre, and
// the turn stops while the spinner is hidden or its window is not showing.
Item {
    id: root

    property color color: Theme.blue
    property real size: 14
    readonly property alias turn: turn
    readonly property real stroke: Math.max(1.5, size / 8)

    implicitWidth: size
    implicitHeight: size

    Item {
        id: dial

        width: root.size
        height: root.size
        anchors.centerIn: parent
        transformOrigin: Item.Center
        antialiasing: true

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: root.color
                strokeWidth: root.stroke
                fillColor: "transparent"
                capStyle: ShapePath.RoundCap

                PathAngleArc {
                    centerX: root.size / 2
                    centerY: root.size / 2
                    radiusX: (root.size - root.stroke) / 2
                    radiusY: radiusX
                    startAngle: 0
                    sweepAngle: 270
                }
            }
        }

        RotationAnimation on rotation {
            id: turn

            running: root.visible && root.opacity > 0 && (root.Window.window?.visible ?? false)
            from: 0
            to: 360
            duration: 900
            loops: Animation.Infinite
        }
    }
}
