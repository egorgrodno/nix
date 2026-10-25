pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The bosun daemon as `bosun watch` streams it: the Claude Code sessions it
// runs and the decisions waiting on an answer. The stream ends whenever the
// daemon stops, and starts again a few seconds later. Answers go through the
// `bosun` command, one at a time.
Singleton {
    id: root

    // False until the daemon answers, as on a host that runs none.
    property bool connected: false
    // Each as `bosun status --json` gives it.
    property var sessions: []
    property var decisions: []
    readonly property var mine: decisions.filter(d => d.holder === "user")
    readonly property var masters: decisions.filter(d => d.holder === "master")
    readonly property bool working: sessions.some(s => s.status === "busy" || s.status === "waiting")
    // Why the last answer failed, until the next one.
    property string error: ""
    readonly property ShellScreen screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null

    // The module on the focused screen opens or closes its panel.
    signal toggleRequested

    function approve(id) {
        send(["approve", id]);
    }

    function deny(id) {
        send(["deny", id]);
    }

    function reply(id, answer) {
        send(["reply", id, answer]);
    }

    function dismiss(id) {
        send(["dismiss", id]);
    }

    // `bosun attach` has the daemon resume a stopped session before `claude
    // attach`, which would start Claude Code's supervisor in this kitty. `claude
    // attach` leaves the session running when it exits, as on Ctrl+Z.
    function attach(session) {
        Launcher.run([Programs.kitty, "-e", Programs.bosun, "attach", session.id]);
    }

    function send(args) {
        cli.queue = [...cli.queue, args];
        cli.next();
    }

    function receive(line) {
        let message;
        try {
            message = JSON.parse(line);
        } catch (e) {
            return;
        }
        // The daemon leaves out an empty list.
        if (message.type === "snapshot") {
            sessions = message.sessions ?? [];
            decisions = message.decisions ?? [];
            connected = true;
            return;
        }
        const event = message.event;
        switch (event?.kind) {
        case "sessions":
            sessions = event.sessions ?? [];
            break;
        // An escalated decision comes again, now held by the user.
        case "decision":
            decisions = [...decisions.filter(d => d.id !== event.decision.id), event.decision].sort((a, b) => Number(a.id) - Number(b.id));
            break;
        case "settled":
            decisions = decisions.filter(d => d.id !== event.id);
            break;
        }
    }

    Process {
        id: watch

        running: true
        command: [Programs.bosun, "watch"]
        stdout: SplitParser {
            onRead: line => root.receive(line)
        }
        onExited: {
            root.connected = false;
            root.sessions = [];
            root.decisions = [];
            retry.start();
        }
    }

    Timer {
        id: retry

        interval: 5000
        onTriggered: watch.running = true
    }

    Process {
        id: cli

        property var queue: []

        function next() {
            if (running || queue.length === 0)
                return;
            command = [Programs.bosun].concat(queue[0]);
            queue = queue.slice(1);
            running = true;
        }

        stderr: StdioCollector {
            onStreamFinished: root.error = text.trim().replace(/^bosun: /, "")
        }
        onExited: Qt.callLater(next)
    }

    IpcHandler {
        target: "bosun"

        function toggle(): void {
            root.toggleRequested();
        }
    }
}
