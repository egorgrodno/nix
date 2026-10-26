import QtQuick
import Quickshell

// The bosun fleet: a robot, blue while a session is in its turn, a dot for
// each worker, and how many decisions wait on the user, yellow while any does.
// A dot is blue in a turn, yellow blocked in its own prompt, grey idle, and a
// ring once stopped. Click opens the bosun panel.
Pill {
    id: agents

    readonly property int count: Bosun.mine.length
    readonly property string fleet: {
        const names = {
            turn: "in a turn",
            blocked: "blocked",
            idle: "idle",
            stopped: "stopped"
        };
        const counts = [];
        for (const activity of Object.keys(names)) {
            const n = Bosun.activities.filter(a => a === activity).length;
            if (n > 0)
                counts.push(`${n} ${names[activity]}`);
        }
        return counts.length > 0 ? `Workers: ${counts.join(", ")}` : "";
    }
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
    tooltip: {
        const waiting = count === 0 ? "Nothing waits on you" : count === 1 ? "1 decision waits on you" : `${count} decisions wait on you`;
        return fleet ? `${fleet} · ${waiting}` : waiting;
    }
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

    Row {
        anchors.verticalCenter: parent.verticalCenter
        visible: Bosun.activities.length > 0
        spacing: 3

        Repeater {
            model: Bosun.activities

            Rectangle {
                required property string modelData

                width: 7
                height: 7
                radius: 3.5
                color: {
                    switch (modelData) {
                    case "turn":
                        return Theme.blue;
                    case "blocked":
                        return Theme.yellow;
                    case "idle":
                        return Theme.foregroundMuted;
                    }
                    return "transparent";
                }
                border.width: modelData === "stopped" ? 1.5 : 0
                border.color: Theme.foregroundMuted
            }
        }
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
