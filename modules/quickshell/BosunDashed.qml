import QtQuick
import QtQuick.Shapes

// A dashed yellow outline on a faint yellow fill, behind what has yet to be
// dealt with. It fills its parent.
Shape {
    id: dashed

    property real radius: 4

    anchors.fill: parent
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeColor: Theme.alpha(Theme.yellow, 0.6)
        strokeWidth: 1
        strokeStyle: ShapePath.DashLine
        dashPattern: [4, 3]
        fillColor: Theme.alpha(Theme.yellow, 0.05)

        PathRectangle {
            x: 0.5
            y: 0.5
            width: dashed.width - 1
            height: dashed.height - 1
            radius: dashed.radius
        }
    }
}
