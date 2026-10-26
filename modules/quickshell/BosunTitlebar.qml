pragma ComponentBehavior: Bound

import QtQuick

// bosun's name, the fleet's sessions counted by state, the decisions the
// master holds, then Pause all, or Resume while paused, and New worker.
Item {
    id: bar

    // While a first press of Pause all, or of p, has armed it.
    property bool pauseArmed: false
    // While the New worker form is open.
    property bool spawning: false
    readonly property var counts: {
        const fleet = Bosun.sessions.filter(s => s.node !== "desk").map(s => BosunLook.stateOf(s));
        return BosunLook.stateOrder.map(key => ({
                    key: key,
                    n: fleet.filter(k => k === key).length
                })).filter(c => c.n > 0);
    }

    signal pauseClicked
    signal resumeClicked
    signal newWorkerClicked

    height: 52

    Row {
        anchors.left: parent.left
        anchors.leftMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        spacing: 22

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            BarText {
                anchors.verticalCenter: parent.verticalCenter
                text: BosunLook.robot
                color: Bosun.working ? Theme.blue : Theme.foregroundStrong
            }

            BarText {
                anchors.verticalCenter: parent.verticalCenter
                text: "bosun"
                font.weight: Font.DemiBold
            }
        }

        Repeater {
            model: bar.counts

            Count {
                required property var modelData

                glyph: BosunLook.states[modelData.key].glyph
                glyphColor: BosunLook.stateColor(modelData.key)
                n: modelData.n
                word: BosunLook.states[modelData.key].word
            }
        }

        // Only a count: the master answers these, and the user only the ones
        // it passes on.
        Count {
            visible: Bosun.masters.length > 0
            glyph: BosunLook.master
            n: Bosun.masters.length
            word: "with the master"
        }
    }

    Row {
        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.verticalCenter: parent.verticalCenter
        visible: Bosun.connected
        spacing: 8

        TextButton {
            visible: !Bosun.paused || Bosun.fleetOp === "pause"
            enabled: Bosun.fleetOp === ""
            text: Bosun.fleetOp === "pause" ? `${BosunLook.pause}  Pausing…` : bar.pauseArmed ? `${BosunLook.pause}  Pause every session?` : `${BosunLook.pause}  Pause all`
            hoverFill: Theme.alpha(Theme.yellow, 0.5)
            lit: bar.pauseArmed
            onClicked: bar.pauseClicked()
        }

        TextButton {
            visible: Bosun.paused && Bosun.fleetOp !== "pause"
            enabled: Bosun.fleetOp === ""
            text: Bosun.fleetOp === "unpause" ? `${BosunLook.play}  Resuming…` : `${BosunLook.play}  Resume`
            hoverFill: Theme.alpha(Theme.yellow, 0.5)
            lit: bar.pauseArmed
            onClicked: bar.resumeClicked()
        }

        TextButton {
            text: `${BosunLook.plus}  New worker`
            lit: bar.spawning
            hoverFill: lit ? Theme.alpha(Theme.blue, 0.5) : Theme.tint(0.12)
            onClicked: bar.newWorkerClicked()
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.tint(0.08)
    }

    // A glyph, a number and a word.
    component Count: Row {
        id: count

        property string glyph
        property color glyphColor: Theme.foregroundMuted
        property int n
        property string word

        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        BarText {
            anchors.verticalCenter: parent.verticalCenter
            text: count.glyph
            color: count.glyphColor
            font.pixelSize: 14
        }

        BarText {
            anchors.verticalCenter: parent.verticalCenter
            text: `${count.n}`
            font.pixelSize: 14
        }

        BarText {
            anchors.verticalCenter: parent.verticalCenter
            text: count.word
            color: Theme.foregroundMuted
            font.pixelSize: 14
        }
    }
}
