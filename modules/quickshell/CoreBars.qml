import QtQuick
import Quickshell

// A column per core, graded as Meter is, on one track: a track per column
// shows the uneven widths a fractional scale rounds them to.
Rectangle {
    id: bars

    // Screen.devicePixelRatio is the integer wl_output scale, not the
    // fractional one the window renders at.
    readonly property real dpr: QsWindow.window?.devicePixelRatio ?? 1
    // Whole device pixels, so a fractional scale rounds every column alike.
    readonly property real column: Math.round(2 * dpr) / dpr
    readonly property real gap: Math.max(1, Math.round(dpr)) / dpr

    implicitWidth: columns.implicitWidth
    height: 18
    color: Theme.tint(0.06)

    Row {
        id: columns

        height: parent.height
        spacing: bars.gap

        Repeater {
            model: Stats.cores

            Item {
                required property int modelData

                width: bars.column
                height: parent.height

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(1, Math.round(parent.height * parent.modelData / 100))
                    color: Stats.loadColor(parent.modelData / 100, Theme.blue)
                }
            }
        }
    }
}
