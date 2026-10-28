pragma ComponentBehavior: Bound

import QtQuick

// The sidebar's toggle, bosun's name, the fleet's sessions counted by
// state, the decisions the master holds, then Pause all, or Resume while
// paused, New worker, and a button that shrinks the panel to the overview.
Item {
    id: bar

    // While a first press of Pause all, or of p, has armed it.
    property bool pauseArmed: false
    // Whether the key armed it, rather than a click.
    property bool pauseByKey: false
    // While the New worker form is open.
    property bool spawning: false
    // While the sidebar shows, else its rail.
    property bool sidebarOpen: true

    signal pauseClicked
    signal resumeClicked
    signal newWorkerClicked
    signal sidebarToggled
    signal overviewClicked

    height: 52

    BosunIconButton {
        id: sidebarButton

        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: BosunLook.dockLeft
        lit: bar.sidebarOpen
        tip: bar.sidebarOpen ? "Collapse the sidebar" : "Open the sidebar"
        onClicked: bar.sidebarToggled()
    }

    Row {
        anchors.left: sidebarButton.right
        anchors.leftMargin: 12
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
            model: BosunLook.fleetCounts

            BosunCount {
                required property var modelData

                stateKey: modelData.key
                n: modelData.n
                word: BosunLook.states[modelData.key].word
            }
        }

        // Only a count: the master answers these, and the user only the ones
        // it passes on.
        BosunCount {
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
        spacing: 8

        TextButton {
            height: 32
            visible: Bosun.connected && (!Bosun.paused || Bosun.fleetOp === "pause")
            enabled: Bosun.fleetOp === ""
            text: Bosun.fleetOp === "pause" ? `${BosunLook.pause}  Pausing…` : bar.pauseArmed ? `${BosunLook.pause}  ${bar.pauseByKey ? "Press p again to pause" : "Click again to pause"}` : `${BosunLook.pause}  Pause all`
            hoverFill: Theme.alpha(Theme.yellow, 0.5)
            lit: bar.pauseArmed
            onClicked: bar.pauseClicked()
        }

        TextButton {
            height: 32
            visible: Bosun.connected && Bosun.paused && Bosun.fleetOp !== "pause"
            enabled: Bosun.fleetOp === ""
            text: Bosun.fleetOp === "unpause" ? `${BosunLook.play}  Resuming…` : bar.pauseArmed ? `${BosunLook.play}  Press p again to resume` : `${BosunLook.play}  Resume`
            hoverFill: Theme.alpha(Theme.yellow, 0.5)
            lit: bar.pauseArmed
            onClicked: bar.resumeClicked()
        }

        TextButton {
            height: 32
            visible: Bosun.connected
            text: `${BosunLook.plus}  New worker`
            lit: bar.spawning
            hoverFill: lit ? Theme.alpha(Theme.blue, 0.5) : Theme.tint(0.12)
            onClicked: bar.newWorkerClicked()
        }

        BosunIconButton {
            text: BosunLook.collapse
            tip: "Shrink to the overview"
            onClicked: bar.overviewClicked()
        }
    }

    Rectangle {
        anchors.bottom: parent.bottom
        width: parent.width
        height: 1
        color: Theme.tint(0.08)
    }
}
