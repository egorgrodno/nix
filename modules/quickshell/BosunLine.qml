import QtQuick

// A line that opens at a click: a chevron, a glyph, what it is, and on the
// right a word on how it went. What it opens is the caller's, which follows
// `open` and answers `toggled`.
Item {
    id: line

    property string glyph
    property color glyphColor: Theme.foregroundMuted
    property string label
    property color labelColor: Theme.foregroundMain
    property bool mono: false
    property bool opens: true
    property bool open: false
    // Running: a spinner takes the chevron's place and the text turns blue.
    property bool lit: false
    property string aside
    property color asideColor: Theme.foregroundMuted
    property bool asideMono: false
    // A diff's counts, or -1 for none.
    property int added: -1
    property int removed: -1

    signal toggled

    width: parent?.width ?? 0
    height: 22

    Row {
        id: lead

        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // The chevron's box holds the spinner's place, so the row's width
        // does not change as a call starts or ends. Not hidden by opacity,
        // which the spinner would inherit.
        BarText {
            anchors.verticalCenter: parent.verticalCenter
            text: line.open ? BosunLook.chevronDown : BosunLook.chevronRight
            color: line.lit || !line.opens ? "transparent" : Theme.foregroundMuted
            font.pixelSize: 14

            Loader {
                anchors.centerIn: parent
                active: line.lit
                sourceComponent: BosunSpinner {
                    size: 12
                }
            }
        }

        BarText {
            anchors.verticalCenter: parent.verticalCenter
            text: line.glyph
            color: line.lit ? Theme.blue : line.glyphColor
            font.pixelSize: 14
        }
    }

    BarText {
        anchors.left: lead.right
        anchors.leftMargin: 8
        anchors.right: tail.left
        anchors.rightMargin: 16
        anchors.verticalCenter: parent.verticalCenter
        elide: Text.ElideRight
        text: line.label
        color: line.lit ? Theme.blue : line.labelColor
        font.family: line.mono ? Theme.fontMono : Theme.fontUI
        font.pixelSize: line.mono ? 13 : 14
    }

    Row {
        id: tail

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        BarText {
            visible: line.added >= 0
            text: `+${line.added}`
            color: Theme.green
            font.pixelSize: 13
        }

        BarText {
            visible: line.removed >= 0
            text: `−${line.removed}`
            color: Theme.red
            font.pixelSize: 13
        }

        BarText {
            width: Math.min(implicitWidth, 320)
            visible: line.aside !== ""
            elide: Text.ElideRight
            text: line.aside
            color: line.asideColor
            font.family: line.asideMono ? Theme.fontMono : Theme.fontUI
            font.pixelSize: 13
        }
    }

    MouseArea {
        anchors.fill: parent
        enabled: line.opens
        cursorShape: Qt.PointingHandCursor
        onClicked: line.toggled()
    }
}
