import QtQuick
import QtQuick.Shapes

// The last minute of upload above the midline and download below it, each
// scaled to its own peak, so a quiet direction still shows its shape.
Shape {
    id: spark

    property var up: []
    property var down: []
    // The smallest peak a half scales to, so idle traffic draws flat.
    property real floor: 8192
    property color color: Theme.foregroundMuted
    readonly property int samples: 30

    // The area between the midline and the rates, above it for sign 1.
    function area(values, sign) {
        if (values.length < 2)
            return [];
        const mid = height / 2;
        const peak = Math.max(floor, ...values);
        const step = width / (samples - 1);
        const start = samples - values.length;
        return [Qt.point(start * step, mid)].concat(values.map((v, i) => Qt.point((start + i) * step, mid - sign * (mid - 1) * v / peak)), [Qt.point(width, mid)]);
    }

    width: 40
    height: 26
    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        fillColor: Theme.alpha(spark.color, 0.35)
        strokeColor: spark.color
        strokeWidth: 1

        PathPolyline {
            path: spark.area(spark.up, 1)
        }
    }

    ShapePath {
        fillColor: Theme.alpha(spark.color, 0.35)
        strokeColor: spark.color
        strokeWidth: 1

        PathPolyline {
            path: spark.area(spark.down, -1)
        }
    }

    Rectangle {
        y: Math.round(parent.height / 2)
        width: parent.width
        height: 1
        color: Qt.rgba(1, 1, 1, 0.12)
    }
}
