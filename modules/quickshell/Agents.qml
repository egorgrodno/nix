import QtQuick
import Quickshell

// The bosun fleet: a robot, blue while a session is in its turn, and how many
// decisions wait on the user, yellow while any does. Click opens the bosun
// panel.
Pill {
    id: agents

    readonly property int count: Bosun.mine.length
    // Half the room a single digit leaves in its slot, moved before the glyph,
    // as on the bell.
    readonly property int slack: Math.round((figure.width - figure.implicitWidth) / 2)

    function toggle() {
        if (panel.active)
            panel.item.close();
        else
            panel.active = true;
    }

    leftPadding: 12 + slack
    rightPadding: 12 - slack
    lit: panel.active
    tooltip: count === 0 ? "Nothing waits on you" : count === 1 ? "1 decision waits on you" : `${count} decisions wait on you`
    onClicked: button => {
        if (button === Qt.LeftButton)
            toggle();
    }

    // The bind's toggle and the notification's click, for the module on the
    // focused screen.
    Connections {
        target: Bosun

        function onToggleRequested() {
            if (agents.QsWindow.window?.screen === Bosun.screen)
                agents.toggle();
        }

        function onOpenRequested() {
            if (agents.QsWindow.window?.screen === Bosun.screen)
                panel.active = true;
        }
    }

    BarText {
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F06A9}"
        color: Bosun.working ? Theme.blue : Theme.foregroundStrong
    }

    Figure {
        id: figure

        anchors.verticalCenter: parent.verticalCenter
        widest: "99"
        text: `${Math.min(agents.count, 99)}`
        color: agents.count > 0 ? Theme.yellow : Theme.foregroundFaint
    }

    LazyLoader {
        id: panel

        BosunPanel {
            module: agents
            onDismissed: panel.active = false
        }
    }
}
