import QtQuick

// A fact in a header: a session's context use as a bar and "84k / 1M".
Row {
    id: fact

    property var context: null

    visible: context !== null && context !== undefined
    spacing: 6

    BarText {
        anchors.verticalCenter: parent.verticalCenter
        text: BosunLook.gauge
        color: Theme.foregroundMuted
        font.pixelSize: 14
    }

    BosunContextBar {
        anchors.verticalCenter: parent.verticalCenter
        context: fact.context
    }

    BarText {
        anchors.verticalCenter: parent.verticalCenter
        text: BosunLook.contextText(fact.context)
        color: Theme.foregroundMuted
        font.pixelSize: 14
    }
}
