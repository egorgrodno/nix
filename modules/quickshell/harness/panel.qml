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

        // The screen's size, as "1440x900".
        function screenSize(): string {
            return `${bar.screen?.width}x${bar.screen?.height}`;
        }

        // The seq of the first log entry of `kind`, for `select log:<seq>`.
        function logSeq(kind: string): string {
            const entry = Bosun.log.find(e => e.kind === kind);
            return entry ? `${entry.seq}` : "";
        }

        // The fleet with `count` more workers, as the daemon's sessions event
        // sends it.
        function fleet(count: int): string {
            Bosun.receive(JSON.stringify({
                event: {
                    kind: "sessions",
                    sessions: data.fleet(count)
                }
            }));
            return "ok";
        }

        // A decision `id` from `node` comes to wait on the user.
        function decide(id: string, node: string): string {
            Bosun.receive(JSON.stringify({
                event: {
                    kind: "decision",
                    decision: data.decision(id, node)
                }
            }));
            return "ok";
        }

        // The decision `id` is settled, however.
        function settle(id: string): string {
            Bosun.receive(JSON.stringify({
                event: {
                    kind: "settled",
                    id
                }
            }));
            return "ok";
        }

        // Shows or clears the pause banner and the error strip.
        function banners(on: bool): string {
            Bosun.paused = on;
            Bosun.error = on ? "the daemon cannot start panel-ipc: no such repository" : "";
            return "ok";
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
