pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The bosun daemon as `bosun watch` streams it: the Claude Code sessions it
// runs, the decisions waiting on an answer and the fleet's log.
// The stream ends whenever the daemon stops, and starts again a few seconds
// later. Answers and commands go through the `bosun` command, one at a time,
// with a pause or unpause beside them. A decision that comes to wait on the
// user raises a notification, as a reply of the desk's does while no panel
// shows.
Singleton {
    id: root

    // False until the daemon answers, as on a host that runs none.
    property bool connected: false
    // False from when the panel opens until its open animation finishes, and
    // true with no panel.
    property bool panelEntered: true
    // While `bosun pause` holds every session stopped, until `bosun unpause`.
    property bool paused: false
    // "pause" or "unpause" while the panel's runs: each stops or resumes the
    // sessions one by one.
    // "compact desk", "clear master" and the like while that command runs.
    readonly property string contextOp: contextRun.running ? contextRun.op : ""
    readonly property string fleetOp:fleet.running ? fleet.op : ""
    // Each as `bosun status --json` gives it.
    property var sessions: []
    readonly property var master: sessions.find(s => s.node === "master") ?? null
    // The session the user talks to, which `tell` reaches.
    readonly property var desk: sessions.find(s => s.node === "desk") ?? null
    property var decisions: []
    readonly property var mine: decisions.filter(d => d.holder === "user")
    readonly property var masters: decisions.filter(d => d.holder === "master")
    // The master and its workers, depth first, each session under its parent,
    // as `bosun status` prints it.
    readonly property var tree: {
        const children = new Map();
        for (const s of sessions.filter(s => s.node !== "desk")) {
            const parent = s.parent ?? "";
            children.set(parent, [...(children.get(parent) ?? []), s]);
        }
        const rows = [];
        const walk = parent => {
            for (const s of children.get(parent) ?? []) {
                rows.push(s);
                walk(s.node);
            }
        };
        walk("");
        return rows;
    }
    // A worker under the master, which the daemon's clear of the master refuses.
    readonly property bool hasWorkers: sessions.some(s => s.node !== "master" && s.node !== "desk")
    readonly property bool working:sessions.some(s => s.status === "busy" || s.status === "waiting")
    // What each worker does, as `activityOf` names it, in turn first: those
    // gone from Claude Code's listing left out.
    readonly property var activities: {
        const order = ["turn", "blocked", "paused", "idle", "stopped"];
        return sessions.filter(s => s.node !== "master" && s.node !== "desk").map(activityOf).filter(a => a !== "").sort((a, b) => order.indexOf(a) - order.indexOf(b));
    }
    // The decisions the desk answered on the user's word, oldest first: the
    // `decision`, the `behavior` or `text` it gave and the user's `words`.
    property var answered: []
    // The fleet's log, oldest first, the latest 200 as the daemon keeps them:
    // each entry with its `seq`, `at`, `kind`, `by` and what its kind carries.
    property var log: []
    // How many of the log's entries came today, counted back from the newest.
    readonly property int logToday: {
        const midnight = new Date().setHours(0, 0, 0, 0);
        let n = 0;
        for (let i = log.length - 1; i >= 0 && Date.parse(log[i].at) >= midnight; i--)
            n++;
        return n;
    }
    // Why the last command failed, until the next one.
    property string error: ""
    // The node whose model switch has not finished.
    property string switching: ""
    readonly property ShellScreen screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    // The BosunPanel of each panel that shows, one per screen at most.
    property var panels: []
    readonly property int panelsOpen: panels.length
    // The one a script's IPC call reaches: the open panel on the focused
    // screen, else the newest.
    readonly property var panel: {
        const open = panels.filter(v => v.open);
        return open.find(v => v.screen === screen) ?? open[open.length - 1] ?? null;
    }
    // The desk's latest reply, its `activity` text and when, which a
    // notification told of or the snapshot already held.
    property string deskReply: ""
    // Claude Code's aliases, which the panel offers.
    readonly property var models: ["fable", "opus", "sonnet", "haiku"]
    // What a worker's effort may be, lowest first.
    readonly property var efforts: ["low", "medium", "high", "xhigh", "max"]

    // The module on the focused screen opens or closes its panel.
    signal toggleRequested
    // The module on the focused screen opens its panel.
    signal openRequested
    // A command sent through `send` has exited, with status 0 if `ok`.
    signal finished(var args, bool ok)
    // A say or tell to `node` is queued, with the args `finished` reports.
    signal sending(string node, var args)

    onFinished: args => {
        if (args[0] === "model")
            switching = "";
    }

    // "turn", "blocked" in its own prompt or on an open decision, "idle",
    // "paused" in its turn, which unpausing resumes, "stopped", or "" once
    // gone.
    function activityOf(session) {
        if (session.status === "exited")
            return "";
        if (session.paused)
            return "paused";
        if (session.killed || session.status === "stopped")
            return "stopped";
        if (decisions.some(d => d.node === session.node))
            return "blocked";
        switch (session.status) {
        case "waiting":
            return "blocked";
        case "idle":
            return "idle";
        }
        return "turn";
    }

    // A decision's kind, a notice of the session's own permission prompt, which
    // approve and deny answer, as a permission.
    function kindOf(decision) {
        return decision.kind === "notice" && decision.prompt === true ? "permission" : decision.kind;
    }

    // What a permission asks to run or touch, as `bosun status` names it.
    function detailOf(decision) {
        const input = decision.input ?? {};
        for (const key of ["command", "file_path", "notebook_path", "url", "pattern"])
            if (typeof input[key] === "string")
                return input[key];
        return JSON.stringify(input);
    }

    // The whole of a permission's call, as blocks for BosunCallBlock:
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
            shown.add("timeout");
            if (typeof input.timeout === "number" && input.timeout > 0)
                blocks.push({
                    kind: "note",
                    label: "Run limit of the command itself, once allowed",
                    text: BosunLook.span(input.timeout)
                });
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
    // its tag. A click opens the panel on it. The master's note comes first,
    // in bold, since it may say the decision needs no answer. A permission
    // takes Deny and Approve there only when all of it, the note included,
    // shows in the lines a card shows before its expander.
    function notify(decision) {
        const d = decision;
        const kind = kindOf(d);
        const summary = kind === "permission" ? `${d.node} asks to use ${d.tool}` : d.kind === "question" ? `${d.node} asks` : `${d.node} says`;
        const text = kind === "permission" ? callOf(d).filter(b => b.kind !== "note").map(b => b.label ? `${b.label}: ${b.text}` : b.text) : [d.kind === "question" ? d.question : d.note];
        const note = d.kind !== "notice" && d.note ? `Master: ${d.note}`.split("\n") : [];
        const lines = note.concat(text.join("\n").split("\n"));
        const whole = lines.length <= 3 && lines.every(line => {
            bodyLine.text = line;
            return bodyLine.advanceWidth <= 280;
        });
        const answers = kind === "permission" && whole ? ["--action=deny=Deny", "--action=approve=Approve"] : [];
        // The bar reads a body as markup.
        const escape = line => line.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        const body = lines.slice(0, 20).map((line, i) => i < note.length ? `<b>${escape(line)}</b>` : escape(line)).join("\n");
        notifier.post(d.id, answers.concat(["--", summary, body]));
    }

    // The desk ended a turn on text, its activity says: a reply, which raises
    // a notification unless a panel shows or `post` is false.
    function noteDesk(post) {
        const activity = desk?.activity;
        if (!activity?.text || activity.tool)
            return;
        const reply = `${activity.at} ${activity.text}`;
        if (reply === deskReply)
            return;
        deskReply = reply;
        if (post && panelsOpen === 0)
            deskNotifier.post(activity.text);
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

    // What a decision asks, on one line: what a permission acts on, a
    // question, or a notice's text.
    function summaryOf(decision) {
        const d = decision;
        if (kindOf(d) === "permission")
            return detailOf(d);
        return (d.kind === "question" ? d.question : d.note) ?? "";
    }

    // The log's `settled` entry for the decision, once it has come.
    function settledEntry(id) {
        for (let i = log.length - 1; i >= 0; i--)
            if (log[i].kind === "settled" && log[i].decision?.id === id)
                return log[i];
        return null;
    }

    function approve(id) {
        send(["approve", id]);
    }

    // `bosun deny` passes a note on as what to do instead.
    function deny(id, note) {
        send(["deny", id].concat(note ? [note] : []));
    }

    function reply(id, answer) {
        send(["reply", id, answer]);
    }

    function dismiss(id) {
        send(["dismiss", id]);
    }

    // The daemon routes it to the desk, or to the master when there is none.
    function tell(text) {
        const args = ["tell", text];
        sending(desk ? "desk" : "master", args);
        send(args);
    }

    // A worker under the master, on the daemon's worker model and effort when
    // `model` and `effort` are empty.
    function spawn(name, repo, prompt, model, effort) {
        send(["spawn"].concat(model ? ["-model", model] : [], effort ? ["-effort", effort] : [], ["--", name, repo, prompt]));
    }

    function kill(node) {
        send(["kill", node]);
    }

    // The master's or the desk's context, summarised and kept. The daemon
    // answers once the compaction ends, up to five minutes on, so it runs
    // beside `cli` and holds no answer back.
    function compact(node) {
        contextRun.start("compact", node);
    }

    // A new conversation for the master or the desk, which the daemon
    // refuses for the master while any worker exists.
    function clear(node) {
        contextRun.start("clear", node);
    }

    // As the user: a stopped session resumes with it, a running one reads it
    // between tool calls, and a text starting with / runs as a command.
    function say(node, text) {
        const args = ["say", node, text];
        sending(node, args);
        send(args);
    }

    // Ends the session's turn, which reaches its parent as a turn end.
    function interrupt(node) {
        send(["interrupt", node]);
    }

    // The daemon resumes the master or the desk on another model, effort or
    // both, keeping its conversation; an empty one stays as it is. A desk in
    // its turn can take 30 s to answer, which `switching` covers.
    function model(node, model, effort) {
        switching = node;
        send(["model"].concat(effort ? ["-effort", effort] : [], [node], model ? [model] : []));
    }

    function pause() {
        fleet.run("pause");
    }

    function unpause() {
        fleet.run("unpause");
    }

    // When the session asked the decision: its `asked`, else that of a log
    // entry naming it, else when the log had it asked, else "". A daemon
    // older than `asked` leaves only the log.
    function askedAt(decision) {
        if (!decision)
            return "";
        if (decision.asked)
            return decision.asked;
        const entry = log.find(e => e.decision?.id === decision?.id && (e.decision.asked || ["decision", "escalated"].includes(e.kind)));
        return entry?.decision?.asked || entry?.at || "";
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
            answered = message.answered ?? [];
            log = message.log ?? [];
            paused = message.paused === true;
            connected = true;
            noteDesk(false);
            return;
        }
        const event = message.event;
        switch (event?.kind) {
        case "sessions":
            sessions = event.sessions ?? [];
            noteDesk(true);
            break;
        case "activity":
            sessions = sessions.map(s => s.node === event.node ? Object.assign({}, s, {
                activity: event.activity
            }) : s);
            if (event.node === "desk")
                noteDesk(true);
            break;
        case "context":
            sessions = sessions.map(s => s.node === event.node ? Object.assign({}, s, {
                context: event.context
            }) : s);
            break;
        case "runs":
            sessions = sessions.map(s => s.node === event.node ? Object.assign({}, s, {
                runs: event.runs
            }) : s);
            break;
        case "decision":
            add(event.decision);
            break;
        case "settled":
            decisions = decisions.filter(d => d.id !== event.id);
            break;
        case "answered":
            if (event.answered)
                answered = [...answered, event.answered].slice(-10);
            break;
        case "log":
            if (event.entry)
                log = [...log, event.entry].slice(-200);
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
            root.answered = [];
            root.log = [];
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

    // A compact or clear in flight, one at a time.
    Process {
        id: contextRun

        property string op: ""

        function start(verb, node) {
            if (running)
                return;
            op = `${verb} ${node}`;
            command = [Programs.bosun, verb, node];
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
                // The one thing that moves the panel's selection on its own.
                if (action === "default") {
                    if (notifier.decision !== "")
                        BosunKept.select(`decision:${notifier.decision}`);
                    root.openRequested();
                }
                else if (notifier.decision !== "" && action === "approve")
                    root.approve(notifier.decision);
                else if (notifier.decision !== "" && action === "deny")
                    root.deny(notifier.decision);
            }
        }
        onExited: Qt.callLater(next)
    }

    // Under a tag of its own, so a reply and a decision replace neither.
    Process {
        id: deskNotifier

        property string pending: ""

        function post(text) {
            pending = text;
            if (running)
                running = false;
            else
                next();
        }

        function next() {
            if (running || pending === "")
                return;
            // The bar reads a body as markup.
            const body = pending.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
            command = [Programs.notifySend, "--app-name=bosun", "--hint=string:x-dunst-stack-tag:bosun-desk", "--action=default=Open", "--", "Front desk", body];
            pending = "";
            running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "default") {
                    BosunKept.select("desk");
                    root.openRequested();
                }
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

    // What `act` returns for the panel that shows, "ok" if it returns "", else
    // "error: " and why. Without a panel, the same.
    function drive(act) {
        const why = panel ? act(panel) : "no panel is open";
        return why === "" ? "ok" : `error: ${why}`;
    }

    // For scripts, in place of keystrokes that land in whatever window has the
    // focus. Nothing here sends, interrupts or answers, and an action with two
    // presses stops at the first: those stay the user's. BosunPanel holds the
    // panel's side.
    IpcHandler {
        target: "bosun"

        function toggle(): void {
            root.toggleRequested();
        }

        function open(): void {
            root.openRequested();
        }

        function close(): void {
            for (const p of root.panels)
                p.close();
        }

        function isOpen(): bool {
            return root.panel !== null;
        }

        function select(row: string): string {
            return root.drive(v => v.selectRow(row));
        }

        function focus(where: string): string {
            return root.drive(v => v.focusAt(where));
        }

        function mode(name: string): string {
            return root.drive(v => v.setMode(name));
        }

        function sidebar(how: string): string {
            return root.drive(v => v.setSidebar(how));
        }

        function arm(action: string): string {
            return root.drive(v => v.armAction(action));
        }

        function state(): string {
            return JSON.stringify(Object.assign({
                open: root.panel !== null,
                selected: BosunKept.selected,
                mode: BosunKept.full ? "full" : "overview",
                sidebarOpen: BosunKept.sidebarOpen
            }, root.panel?.panelState()));
        }

        function geometry(): string {
            return root.panel ? JSON.stringify(root.panel.geometry()) : "error: no panel is open";
        }
    }
}
