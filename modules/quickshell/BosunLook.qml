pragma Singleton

import QtQuick
import Quickshell

// The bosun panel's glyphs, the Nerd Font's md-* ones, their colours and the
// words that go with them: a session's state, a decision's kind, a fact and a
// Log entry.
Singleton {
    readonly property string robot: "\u{F06A9}"
    readonly property string clock: "\u{F0150}"
    readonly property string folder: "\u{F0256}"
    readonly property string branch: "\u{F062C}"
    readonly property string chip: "\u{F061A}"
    readonly property string account: "\u{F0013}"
    readonly property string reserved: "\u{F0ECD}"
    readonly property string notice: "\u{F02FD}"
    readonly property string alert: "\u{F002A}"
    readonly property string master: "\u{F0833}"
    readonly property string desk: "\u{F0D70}"
    readonly property string pause: "\u{F03E4}"
    readonly property string play: "\u{F040A}"
    readonly property string plus: "\u{F0415}"
    readonly property string check: "\u{F012C}"
    readonly property string close: "\u{F0156}"
    readonly property string send: "\u{F048A}"
    readonly property string open: "\u{F03CC}"

    readonly property var states: ({
            working: {
                glyph: "\u{F040A}",
                word: "working"
            },
            blocked: {
                glyph: "\u{F182D}",
                word: "blocked"
            },
            paused: {
                glyph: "\u{F03E6}",
                word: "paused"
            },
            limited: {
                glyph: "\u{F051F}",
                word: "usage-limited"
            },
            idle: {
                glyph: "\u{F0904}",
                word: "idle"
            },
            stopped: {
                glyph: "\u{F0667}",
                word: "stopped"
            },
            killed: {
                glyph: "\u{F015D}",
                word: "killed"
            }
        })
    // The titlebar counts them in this order.
    readonly property var stateOrder: ["working", "blocked", "paused", "limited", "idle", "stopped", "killed"]

    // A key of `states`. Claude Code's "waiting" is a session blocked in its
    // own prompt, as one waiting on a decision is too.
    function stateOf(session) {
        if (session.killed)
            return "killed";
        if (session.paused)
            return "paused";
        if (session.limitedUntil)
            return "limited";
        switch (session.status) {
        case "stopped":
        case "exited":
            return "stopped";
        case "waiting":
            return "blocked";
        case "idle":
            return "idle";
        }
        return "working";
    }

    function stateColor(key) {
        switch (key) {
        case "working":
            return Theme.blue;
        case "blocked":
        case "paused":
            return Theme.yellow;
        }
        return Theme.foregroundMuted;
    }

    // The words a state glyph stands for, as its tooltip gives them.
    function stateWords(session) {
        const key = stateOf(session);
        if (key === "limited")
            return `Usage-limited until ${Qt.formatTime(new Date(session.limitedUntil), "HH:mm")}`;
        if (key === "paused")
            return "Paused in its turn, which Resume restarts";
        const words = [states[key].word, session.status, session.state].filter((w, i, all) => w && all.indexOf(w) === i);
        const text = words.join(", ");
        return text.charAt(0).toUpperCase() + text.slice(1);
    }

    function decisionGlyph(decision) {
        if (decision.kind === "question")
            return "\u{F0625}";
        if (decision.kind === "notice")
            return notice;
        switch (decision.tool) {
        case "Bash":
            return "\u{F018D}";
        case "Edit":
        case "MultiEdit":
        case "NotebookEdit":
            return "\u{F0CB6}";
        case "Write":
            return "\u{F0EED}";
        }
        return "\u{F1064}";
    }

    function tilde(path) {
        const home = Quickshell.env("HOME");
        return path?.startsWith(`${home}/`) ? `~${path.slice(home.length)}` : path ?? "";
    }

    // What a decision is, after its session's name: "worker-a's Bash".
    function decisionName(decision) {
        const what = decision.kind === "permission" ? decision.tool : decision.kind;
        return `${decision.node}'s ${what}`;
    }

    // The kinds of log entry the panel shows; any other is one bosun cannot
    // show yet.
    readonly property var logKinds: ["decision", "escalated", "settled", "tell", "message", "spawned", "resumed", "merged", "killed", "paused", "unpaused", "model", "turn_end", "exit"]

    function knows(entry) {
        return logKinds.includes(entry.kind) && (!["decision", "escalated", "settled"].includes(entry.kind) || entry.decision);
    }

    // How a settled entry's decision went: "allowed", "denied", "answered",
    // "dismissed" or "withdrawn".
    function outcomeOf(entry) {
        if (entry.withdrawn)
            return "withdrawn";
        if (entry.decision?.kind === "notice")
            return "dismissed";
        if (entry.behavior === "allow")
            return "allowed";
        if (entry.behavior === "deny")
            return "denied";
        return "answered";
    }

    // Who acted: the user, the master, the desk, bosun, or the session.
    function actorOf(entry) {
        switch (entry.by) {
        case "user":
            return "You";
        case "master":
            return "Master";
        case "desk":
            return "Desk";
        case "bosun":
            return "bosun";
        }
        return entry.from || entry.node || "";
    }

    // What the entry says happened, without its text.
    function logTitle(entry) {
        if (!knows(entry))
            return "bosun can't show this entry yet";
        const d = entry.decision;
        const who = actorOf(entry);
        switch (entry.kind) {
        case "decision":
            return d.kind === "permission" ? `${d.node} asks to use ${d.tool}` : d.kind === "question" ? `${d.node} asks` : `${d.node} says`;
        case "escalated":
            return `Master passed ${decisionName(d)} to you`;
        case "settled":
            {
                const outcome = outcomeOf(entry);
                if (outcome === "withdrawn")
                    return `${decisionName(d)} withdrawn${entry.cause ? ` when ${entry.cause}` : ""}`;
                if (entry.by === "session")
                    return outcome === "answered" ? `${d.node} was answered in its own prompt` : `${decisionName(d)} ${outcome} in its own prompt`;
                if (outcome === "answered")
                    return `${who} answered ${d.node}`;
                return `${who} ${outcome} ${decisionName(d)}`;
            }
        case "tell":
            return `${who} told ${entry.node}`;
        case "message":
            return `${entry.from} to ${entry.node}`;
        case "spawned":
            return `${who} spawned ${entry.node}${entry.repo ? ` in ${tilde(entry.repo)}` : ""}`;
        case "resumed":
            return `${who} gave ${entry.node} a new prompt`;
        case "merged":
            return `${who} merged ${entry.node}`;
        case "killed":
            return `${who} killed ${entry.node}`;
        case "paused":
            return `${who} paused the fleet`;
        case "unpaused":
            return `${who} resumed the fleet`;
        case "model":
            return `${who} switched ${entry.node} to ${[entry.model, entry.effort].filter(part => part).join(" ")}`;
        case "turn_end":
            return `${entry.node} ended its turn`;
        }
        return `${entry.node} stopped`;
    }

    // What follows the title on the entry's line: its text, or what its
    // decision asks.
    function logDetail(entry) {
        if (!knows(entry))
            return entry.kind ?? "";
        const d = entry.decision;
        switch (entry.kind) {
        case "decision":
        case "escalated":
            return Bosun.summaryOf(d);
        case "settled":
            return outcomeOf(entry) === "answered" ? entry.text ?? "" : Bosun.summaryOf(d);
        case "spawned":
            return "";
        }
        return entry.text ?? "";
    }

    // A Log entry on one line, as the sidebar lists it.
    function logLine(entry) {
        const detail = logDetail(entry).split("\n")[0];
        return detail ? `${logTitle(entry)}: ${detail}` : logTitle(entry);
    }

    // "14:02" today, else "Oct 25".
    function timeOf(entry) {
        if (!entry.at)
            return "";
        const at = new Date(entry.at);
        return at.toDateString() === new Date().toDateString() ? Qt.formatTime(at, "HH:mm") : Qt.formatDate(at, "MMM d");
    }

    function logGlyph(entry) {
        if (!knows(entry))
            return alert;
        switch (entry.kind) {
        case "decision":
            return decisionGlyph(entry.decision);
        case "escalated":
            return master;
        case "settled":
            switch (outcomeOf(entry)) {
            case "withdrawn":
                return notice;
            case "denied":
                return "\u{F015A}";
            }
            return "\u{F05E1}";
        case "tell":
            return entry.by === "desk" ? desk : entry.by === "master" ? master : "\u{F12F5}";
        case "message":
            return "\u{F12F5}";
        case "spawned":
            return "\u{F0419}";
        case "resumed":
        case "unpaused":
            return play;
        case "merged":
            return "\u{F062D}";
        case "killed":
            return states.killed.glyph;
        case "paused":
            return states.paused.glyph;
        case "model":
            return chip;
        case "turn_end":
            return states.idle.glyph;
        }
        return states.stopped.glyph;
    }

    function logColor(entry) {
        if (!knows(entry))
            return Theme.yellow;
        switch (entry.kind) {
        case "settled":
            switch (outcomeOf(entry)) {
            case "allowed":
            case "answered":
                return Theme.green;
            case "denied":
                return Theme.red;
            }
            break;
        case "spawned":
            return Theme.blue;
        case "merged":
            return Theme.magenta;
        case "paused":
            return Theme.yellow;
        }
        return Theme.foregroundMuted;
    }
}
