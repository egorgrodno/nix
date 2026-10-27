import QtQuick
import QtQuick.Shapes

// A running state's spinner: a short arc that travels round a faint circle.
// The arc is drawn, not a glyph, as a glyph's box is neither square nor
// centred on its mark. A long arc would read as a shape spinning about its own
// middle, since its mass sits near the circle's centre. The dial stays square,
// centred in whatever box it is given and on whole pixels, and the turn stops
// while the spinner is hidden or its window is not showing.
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
        x: (root.width - width) / 2
        y: (root.height - height) / 2
        transformOrigin: Item.Center
        antialiasing: true

        Shape {
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer

            ShapePath {
                strokeColor: Qt.alpha(root.color, 0.25)
                strokeWidth: root.stroke
                fillColor: "transparent"

                PathAngleArc {
                    centerX: root.size / 2
                    centerY: root.size / 2
                    radiusX: (root.size - root.stroke) / 2
                    radiusY: radiusX
                    startAngle: 0
                    sweepAngle: 360
                }
            }

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
                    sweepAngle: 90
                }
            }
        }

        // The angle comes from the clock, so a spinner its view rebuilds
        // carries on where the last one was rather than jumping back. The
        // snap runs here too, as a binding would not see an ancestor move.
        FrameAnimation {
            id: turn

            running: root.visible && root.opacity > 0 && (root.Window.window?.visible ?? false)
            onTriggered: {
                const at = root.mapToItem(null, (root.width - root.size) / 2, (root.height - root.size) / 2);
                dial.x = (root.width - root.size) / 2 + Math.round(at.x) - at.x;
                dial.y = (root.height - root.size) / 2 + Math.round(at.y) - at.y;
                dial.rotation = Date.now() % 900 / 900 * 360;
            }
        }
    }
}
