pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The bosun daemon as `bosun watch` streams it: the Claude Code sessions it
// runs and the decisions waiting on an answer. The stream ends whenever the
// daemon stops, and starts again a few seconds later. Answers and commands go
// through the `bosun` command, one at a time. A decision that comes to wait on
// the user raises a notification.
Singleton {
    id: root

    // False until the daemon answers, as on a host that runs none.
    property bool connected: false
    // Each as `bosun status --json` gives it.
    property var sessions: []
    readonly property var master: sessions.find(s => s.node === "master") ?? null
    property var decisions: []
    readonly property var mine: decisions.filter(d => d.holder === "user")
    readonly property var masters: decisions.filter(d => d.holder === "master")
    readonly property bool working: sessions.some(s => s.status === "busy" || s.status === "waiting")
    // Why the last command failed, until the next one.
    property string error: ""
    readonly property ShellScreen screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    // Claude Code's aliases, which the panel offers.
    readonly property var models: ["fable", "opus", "sonnet", "haiku"]

    // The module on the focused screen opens or closes its panel.
    signal toggleRequested
    // The module on the focused screen opens its panel.
    signal openRequested
    // A command sent through `send` has exited, with status 0 if `ok`.
    signal finished(var args, bool ok)

    // What a permission asks to run or touch, as `bosun status` names it.
    function detailOf(decision) {
        const input = decision.input ?? {};
        for (const key of ["command", "file_path", "notebook_path", "url", "pattern"])
            if (typeof input[key] === "string")
                return input[key];
        return JSON.stringify(input);
    }

    // As the newest of one notification, which a later one replaces through
    // its tag. A click opens the panel.
    function notify(decision) {
        const d = decision;
        const summary = d.kind === "permission" ? `${d.node} asks to use ${d.tool}` : d.kind === "question" ? `${d.node} asks` : `${d.node} says`;
        const text = d.kind === "permission" ? detailOf(d) : d.kind === "question" ? d.question : d.note;
        const why = d.kind !== "notice" && d.note ? `\n\nMaster: ${d.note}` : "";
        // The bar reads a body as markup.
        const body = (text + why).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        notifier.post([summary, body]);
    }

    // Once nothing waits on the user.
    function withdraw() {
        for (const entry of Notifications.entries)
            if (entry.tag === "bosun")
                entry.notification?.expire();
    }

    onMineChanged: if (mine.length === 0)
        withdraw()

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

    function tell(text) {
        send(["tell", text]);
    }

    // A worker under the master, on the daemon's worker model when `model` is
    // empty.
    function spawn(name, repo, prompt, model) {
        send(["spawn"].concat(model ? ["-model", model] : [], ["--", name, repo, prompt]));
    }

    function kill(node) {
        send(["kill", node]);
    }

    // The daemon resumes the master on it, keeping its conversation.
    function model(name) {
        send(["model", name]);
    }

    // `bosun attach` has the daemon resume a stopped session before `claude
    // attach`, which would start Claude Code's supervisor in this kitty. `claude
    // attach` leaves the session running when it exits, as on Ctrl+Z. A failed
    // attach exits non-zero, and the window then waits so its error is read.
    function attach(session) {
        Launcher.run([Programs.kitty, "-e", Programs.sh, "-c", "\"$0\" attach \"$1\" || { printf '\\nPress Enter to close this window. '; read -r _; }", Programs.bosun, session.id]);
    }

    function send(args) {
        cli.queue = [...cli.queue, args];
        cli.next();
    }

    // An escalated decision comes again, now held by the user.
    function add(decision) {
        const was = decisions.find(d => d.id === decision.id);
        decisions = [...decisions.filter(d => d.id !== decision.id), decision].sort((a, b) => Number(a.id) - Number(b.id));
        if (decision.holder === "user" && was?.holder !== "user")
            notify(decision);
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
        case "decision":
            add(event.decision);
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
        property var args: []

        function next() {
            if (running || queue.length === 0)
                return;
            args = queue[0];
            command = [Programs.bosun].concat(args);
            queue = queue.slice(1);
            running = true;
        }

        stderr: StdioCollector {
            onStreamFinished: root.error = text.trim().replace(/^bosun: /, "")
        }
        onExited: exitCode => {
            root.finished(args, exitCode === 0);
            Qt.callLater(next);
        }
    }

    // One at a time: a post ends the notify-send before, whose notification
    // the next one replaces.
    Process {
        id: notifier

        property var pending: null

        function post(args) {
            pending = args;
            if (running)
                running = false;
            else
                next();
        }

        function next() {
            if (running || pending === null)
                return;
            command = [Programs.notifySend, "--app-name=bosun", "--hint=string:x-dunst-stack-tag:bosun", "--action=default=Open", "--"].concat(pending);
            pending = null;
            running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: if (text.trim() === "default")
                root.openRequested()
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
