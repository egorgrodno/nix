import QtQuick
import QtQuick.Shapes

// The last minute of a rate, scaled to its own peak, so a quiet direction
// still shows its shape.
Shape {
    id: spark

    property var values: []
    // The smallest peak it scales to, so idle traffic draws flat.
    property real floor: 8192
    property color color: Theme.foregroundMuted
    readonly property int samples: 30

    function area() {
        if (values.length < 2)
            return [];
        const peak = Math.max(floor, ...values);
        const step = width / (samples - 1);
        const start = samples - values.length;
        return [Qt.point(start * step, height)].concat(values.map((v, i) => Qt.point((start + i) * step, height - (height - 1) * v / peak)), [Qt.point(width, height)]);
    }

    width: 40
    height: 26
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: Theme.alpha(spark.color, 0.35)
        strokeColor: spark.color
        strokeWidth: 1

        PathPolyline {
            path: spark.area()
        }
    }

    Rectangle {
        y: parent.height - 1
        width: parent.width
        height: 1
        color: Theme.tint(0.12)
    }
}
