import QtQuick

// A column per core, graded as Meter is, on one track: a track per column
// shows the uneven widths a fractional scale rounds them to.
Rectangle {
    implicitWidth: columns.implicitWidth
    height: 18
    color: Theme.tint(0.06)

    Row {
        id: columns

        height: parent.height
        spacing: 1

        Repeater {
            model: Stats.cores

            Item {
                required property int modelData

                width: 2
                height: parent.height

                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(1, Math.round(parent.height * parent.modelData / 100))
                    color: parent.modelData >= 90 ? Theme.red : parent.modelData >= 70 ? Theme.yellow : Theme.foregroundMuted
                }
            }
        }
    }
}
