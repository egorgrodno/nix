import QtQuick

// A labelled share of something, as a meter and its percentage, then an
// amount in a slot as wide as `widest` and a detail after it: a filesystem,
// swap, VRAM.
Row {
    id: row

    property alias label: label.text
    property int labelWidth: 56
    property real value
    property bool graded: true
    property alias amount: amount.text
    property alias widest: amount.widest
    property alias detail: detail.text

    spacing: 8

    BarText {
        id: label

        anchors.verticalCenter: parent.verticalCenter
        width: row.labelWidth
        elide: Text.ElideMiddle
        color: Theme.foregroundMuted
        font.pixelSize: 14
    }

    Meter {
        anchors.verticalCenter: parent.verticalCenter
        width: 120
        value: row.value
        graded: row.graded
    }

    Figure {
        anchors.verticalCenter: parent.verticalCenter
        widest: "100%"
        horizontalAlignment: Text.AlignRight
        text: `${Math.round(row.value * 100)}%`
        font.pixelSize: 14
    }

    Figure {
        id: amount

        anchors.verticalCenter: parent.verticalCenter
        widest: "00.0 GiB"
        horizontalAlignment: Text.AlignRight
        color: Theme.foregroundMuted
        font.pixelSize: 14
    }

    BarText {
        id: detail

        anchors.verticalCenter: parent.verticalCenter
        color: Theme.foregroundMuted
        font.pixelSize: 14
    }
}
