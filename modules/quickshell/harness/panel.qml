import QtQuick
import Quickshell
import Quickshell.Io

// The harness for what needs a real BosunPanel: the bar's Agents pill in a
// window of its own, with the daemon's data faked, so `quickshell ipc` and the
// pill's click reach the panel as they do in the bar. `run.sh` starts it for
// the scripts in `ipc/`, whose environment names the instance.
ShellRoot {
    PanelWindow {
        id: bar

        anchors.top: true
        anchors.left: true
        anchors.right: true
        implicitHeight: Theme.barHeight
        color: Theme.backgroundRaised

        Agents {
            id: agents

            anchors.right: parent.right
        }
    }

    HarnessData {
        id: data
    }

    // For a script to read how many bosun panels show.
    IpcHandler {
        target: "harness"

        function panels(): int {
            return Bosun.panelsOpen;
        }
    }

    Timer {
        interval: 1000
        running: true
        onTriggered: {
            Bosun.receive(JSON.stringify({
                type: "snapshot",
                sessions: data.sessions,
                decisions: data.decisions,
                answered: data.answered,
                log: data.log(50)
            }));
            console.log("HARNESS ready");
        }
    }
}
