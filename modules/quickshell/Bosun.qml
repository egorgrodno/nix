pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The bosun daemon as `bosun watch` streams it: the Claude Code sessions it
// runs, the decisions waiting on an answer and the messages between sessions.
// The stream ends whenever the daemon stops, and starts again a few seconds
// later. Answers and commands go through the `bosun` command, one at a time,
// with a pause or unpause beside them. A decision that comes to wait on the
// user raises a notification.
Singleton {
    id: root

    // False until the daemon answers, as on a host that runs none.
    property bool connected: false
    // While `bosun pause` holds every session stopped, until `bosun unpause`.
    property bool paused: false
    // "pause" or "unpause" while the panel's runs: each stops or resumes the
    // sessions one by one.
    readonly property string fleetOp: fleet.running ? fleet.op : ""
    // Each as `bosun status --json` gives it.
    property var sessions: []
    readonly property var master: sessions.find(s => s.node === "master") ?? null
    property var decisions: []
    readonly property var mine: decisions.filter(d => d.holder === "user")
    readonly property var masters: decisions.filter(d => d.holder === "master")
    readonly property bool working: sessions.some(s => s.status === "busy" || s.status === "waiting")
    // What each worker does, as `activityOf` names it, in turn first: those
    // gone from Claude Code's listing left out.
    readonly property var activities: {
        const order = ["turn", "blocked", "paused", "idle", "stopped"];
        return sessions.filter(s => s.node !== "master").map(activityOf).filter(a => a !== "").sort((a, b) => order.indexOf(a) - order.indexOf(b));
    }
    // What sessions told each other, oldest first, the latest ten as the daemon
    // keeps them: `from` told `node` the `text`.
    property var messages: []
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

    // "turn", "blocked" in its own prompt, as a session waiting on a decision
    // is too, "idle", "paused" in its turn, which unpausing resumes,
    // "stopped", or "" once gone.
    function activityOf(session) {
        if (session.status === "exited")
            return "";
        if (session.paused)
            return "paused";
        if (session.killed || session.status === "stopped")
            return "stopped";
        switch (session.status) {
        case "waiting":
            return "blocked";
        case "idle":
            return "idle";
        }
        return "turn";
    }

    // What a permission asks to run or touch, as `bosun status` names it.
    function detailOf(decision) {
        const input = decision.input ?? {};
        for (const key of ["command", "file_path", "notebook_path", "url", "pattern"])
            if (typeof input[key] === "string")
                return input[key];
        return JSON.stringify(input);
    }

    // The whole of a permission's call, as blocks for the panel's CallBlock:
    // the parts the tool acts on, what takes a command out of the sandbox or
    // onto the network, then every other field of its input, so the user
    // approves nothing unseen.
    function callOf(decision) {
        const input = decision.input ?? {};
        const blocks = [];
        const shown = new Set(["dangerouslyDisableSandbox", "allowed_domains"]);
        const show = (key, kind, label) => {
            shown.add(key);
            const value = input[key];
            if (value !== undefined && value !== null && value !== "")
                blocks.push({
                    kind: kind,
                    label: label,
                    text: typeof value === "string" ? value : JSON.stringify(value, null, 2)
                });
        };
        const replaces = edit => edit.replace_all === true ? "Replaces everywhere" : "Replaces";
        switch (decision.tool) {
        case "Bash":
            show("description", "note", "");
            show("command", "code", "");
            break;
        case "Edit":
            show("file_path", "code", "");
            show("old_string", "removed", replaces(input));
            show("new_string", "added", "With");
            shown.add("replace_all");
            break;
        case "MultiEdit":
            show("file_path", "code", "");
            shown.add("edits");
            for (const edit of input.edits ?? [])
                blocks.push({
                    kind: "removed",
                    label: replaces(edit),
                    text: edit.old_string ?? ""
                }, {
                    kind: "added",
                    label: "With",
                    text: edit.new_string ?? ""
                });
            break;
        case "Write":
            show("file_path", "code", "");
            show("content", "added", "Writes");
            break;
        case "NotebookEdit":
            show("notebook_path", "code", "");
            show("new_source", "added", "Writes");
            break;
        }
        if (input.dangerouslyDisableSandbox === true)
            blocks.push({
                kind: "flag",
                label: "",
                text: "Runs outside the sandbox"
            });
        if (Array.isArray(input.allowed_domains) && input.allowed_domains.length > 0)
            blocks.push({
                kind: "flag",
                label: "",
                text: `Reaches ${input.allowed_domains.join(", ")}`
            });
        for (const key of Object.keys(input))
            if (!shown.has(key))
                show(key, "code", key);
        return blocks;
    }

    // As the newest of one notification, which a later one replaces through
    // its tag. A click opens the panel. A permission takes Deny and Approve
    // there only when all of it, the master's note included, shows in the
    // lines a card shows before its expander.
    function notify(decision) {
        const d = decision;
        const summary = d.kind === "permission" ? `${d.node} asks to use ${d.tool}` : d.kind === "question" ? `${d.node} asks` : `${d.node} says`;
        const text = d.kind === "permission" ? callOf(d).filter(b => b.kind !== "note").map(b => b.label ? `${b.label}: ${b.text}` : b.text) : [d.kind === "question" ? d.question : d.note];
        const lines = text.concat(d.kind !== "notice" && d.note ? [`Master: ${d.note}`] : []).join("\n").split("\n");
        const whole = lines.length <= 3 && lines.every(line => {
            bodyLine.text = line;
            return bodyLine.advanceWidth <= 280;
        });
        const answers = d.kind === "permission" && whole ? ["--action=deny=Deny", "--action=approve=Approve"] : [];
        // The bar reads a body as markup.
        const body = lines.slice(0, 20).join("\n").replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        notifier.post(d.id, answers.concat(["--", summary, body]));
    }

    // Once its decision no longer waits on the user.
    function withdraw() {
        notifier.decision = "";
        for (const entry of Notifications.entries)
            if (entry.tag === "bosun")
                entry.notification?.expire();
    }

    onMineChanged: if (notifier.decision !== "" && !mine.some(d => d.id === notifier.decision))
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

    function pause() {
        fleet.run("pause");
    }

    function unpause() {
        fleet.run("unpause");
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
        // The daemon leaves out an empty list and a false `paused`.
        if (message.type === "snapshot") {
            sessions = message.sessions ?? [];
            decisions = message.decisions ?? [];
            messages = message.messages ?? [];
            paused = message.paused === true;
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
        case "message":
            messages = [...messages, event].slice(-10);
            break;
        case "paused":
        case "unpaused":
            paused = event.kind === "paused";
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
            root.paused = false;
            root.sessions = [];
            root.decisions = [];
            root.messages = [];
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

    // Beside `cli`, so an answer sent while a pause or unpause runs waits for
    // neither.
    Process {
        id: fleet

        property string op: ""

        function run(name) {
            if (running)
                return;
            op = name;
            command = [Programs.bosun, name];
            running = true;
        }

        stderr: StdioCollector {
            onStreamFinished: root.error = text.trim().replace(/^bosun: /, "")
        }
    }

    // One at a time: a post ends the notify-send before, whose notification
    // the next one replaces.
    Process {
        id: notifier

        property var pending: null
        // The id of the decision the notification shows, which its Deny and
        // Approve answer.
        property string decision: ""

        function post(id, args) {
            pending = {
                id: id,
                args: args
            };
            if (running)
                running = false;
            else
                next();
        }

        function next() {
            if (running || pending === null)
                return;
            decision = pending.id;
            command = [Programs.notifySend, "--app-name=bosun", "--hint=string:x-dunst-stack-tag:bosun", "--action=default=Open"].concat(pending.args);
            pending = null;
            running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const action = text.trim();
                if (action === "default")
                    root.openRequested();
                else if (notifier.decision !== "" && action === "approve")
                    root.approve(notifier.decision);
                else if (notifier.decision !== "" && action === "deny")
                    root.deny(notifier.decision);
            }
        }
        onExited: Qt.callLater(next)
    }

    // A line of a notification's body, which a card in the notification
    // panel wraps past 288 pixels.
    TextMetrics {
        id: bodyLine

        font.family: Theme.fontUI
        font.pixelSize: 14
    }

    IpcHandler {
        target: "bosun"

        function toggle(): void {
            root.toggleRequested();
        }
    }
}
