import QtQuick
import QtQuick.Effects

// Under a box that floats over the windows, a panel or a popup, so the window
// border it covers reads as passing beneath it. It reaches at most
// `Theme.shadow` past the box, which the surface leaves room for.
RectangularShadow {
    required property Rectangle target

    anchors.fill: target
    radius: target.radius
    opacity: target.opacity
    blur: Theme.shadow - 2
    offset.y: 2
    color: Qt.rgba(0, 0, 0, 0.7)
}
