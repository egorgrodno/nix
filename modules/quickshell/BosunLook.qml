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
    readonly property string expand: "\u{F0616}"
    readonly property string collapse: "\u{F0615}"
    readonly property string history: "\u{F02DA}"
    readonly property string dockLeft: "\u{F10AA}"
    readonly property string filter: "\u{F0236}"
    readonly property string chevronDown: "\u{F0140}"

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

    // The glyph for a session's activity line: its tool's, or a message's when
    // no call came after the last message.
    function activityGlyph(activity) {
        switch (activity.tool) {
        case undefined:
        case "":
            return "\u{F12F5}";
        case "Read":
        case "Glob":
        case "Grep":
            return "\u{F0349}";
        case "WebFetch":
        case "WebSearch":
            return "\u{F059F}";
        case "Task":
        case "Agent":
            return robot;
        }
        return decisionGlyph({
            kind: "permission",
            tool: activity.tool
        });
    }

    // What follows the glyph: the call's argument, or the message's start.
    function activityText(activity) {
        return activity.tool ? activity.arg ?? activity.tool : activity.text ?? "";
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

    // Who acted, as the expanded Log's Who column names them: "you", "master",
    // "front desk", "bosun" or the session, and for a tell or a message whom
    // it reached.
    function logWho(entry) {
        const name = node => node === "desk" ? "front desk" : node ?? "";
        const role = {
            user: "you",
            master: "master",
            desk: "front desk",
            bosun: "bosun"
        }[entry.by] ?? name(entry.from || entry.node);
        if (!knows(entry))
            return role;
        switch (entry.kind) {
        case "tell":
            return `${role} to ${name(entry.node)}`;
        case "message":
            return `${name(entry.from)} to ${name(entry.node)}`;
        case "decision":
            return entry.decision.node;
        case "settled":
            return entry.by === "session" ? entry.decision.node : role;
        case "turn_end":
        case "exit":
            return entry.node;
        }
        return role;
    }

    // What a permission asks to do: "run go test ./...", or with `ing`
    // "running go test ./...".
    function actOf(decision, ing) {
        const verb = {
            Bash: ["run", "running"],
            Edit: ["edit", "editing"],
            MultiEdit: ["edit", "editing"],
            NotebookEdit: ["edit", "editing"],
            Write: ["write", "writing"]
        }[decision.tool];
        const detail = Bosun.detailOf(decision);
        if (!verb)
            return `${ing ? "using" : "use"} ${decision.tool}: ${detail}`;
        return `${verb[ing ? 1 : 0]} ${detail}`;
    }

    // What happened, after Who, on one line: the expanded Log's What column.
    function logWhat(entry) {
        const line = text => (text ?? "").replace(/\s+/g, " ").trim();
        const after = text => line(text) ? `: ${line(text)}` : "";
        if (!knows(entry))
            return `bosun can't show this entry yet: ${entry.kind ?? ""}`;
        const d = entry.decision;
        switch (entry.kind) {
        case "decision":
            if (d.kind === "permission")
                return `Asked to ${line(actOf(d))}`;
            return d.kind === "question" ? `Asked: ${line(d.question)}` : `Said: ${line(d.note)}`;
        case "escalated":
            return `Passed ${decisionName(d)} to you${after(entry.text)}`;
        case "settled":
            switch (outcomeOf(entry)) {
            case "withdrawn":
                return `${decisionName(d)} withdrawn${entry.cause ? ` when ${entry.cause}` : ""}`;
            case "dismissed":
                return `Dismissed ${decisionName(d)}`;
            case "answered":
                return `Answered ${d.node}${after(entry.text)}`;
            case "allowed":
                return entry.by === "session" ? `Allowed ${line(actOf(d, true))} in its own prompt` : `Allowed ${d.node} to ${line(actOf(d))}`;
            }
            if (entry.by === "session")
                return `Denied ${line(actOf(d, true))} in its own prompt`;
            return `Denied ${d.node} ${line(actOf(d, true))}${entry.text ? `: “${line(entry.text)}”` : ""}`;
        case "tell":
        case "message":
            return line(entry.text);
        case "spawned":
            return `Spawned ${entry.node}${entry.repo ? ` in ${tilde(entry.repo)}` : ""}${entry.model ? ` on ${[entry.model, entry.effort].filter(part => part).join(" ")}` : ""}`;
        case "resumed":
            return `Gave ${entry.node} a new prompt${after(entry.text)}`;
        case "merged":
            return `Merged ${entry.node}${after(entry.text)}`;
        case "killed":
            return `Killed ${entry.node}`;
        case "paused":
            return "Paused the fleet";
        case "unpaused":
            return "Resumed the fleet";
        case "model":
            return `Switched ${entry.node} to ${[entry.model, entry.effort].filter(part => part).join(" ")}`;
        case "turn_end":
            return entry.text ? `Ended its turn: “${line(entry.text)}”` : "Ended its turn";
        }
        return `Stopped${after(entry.text)}`;
    }

    // The expanded Log's kind filter an entry falls under besides All:
    // "decisions", "messages", "sessions", or "" for one bosun cannot show.
    function logGroup(entry) {
        if (!knows(entry))
            return "";
        if (["decision", "escalated", "settled"].includes(entry.kind))
            return "decisions";
        return ["tell", "message"].includes(entry.kind) ? "messages" : "sessions";
    }

    // The sessions an entry is about, which its session filter matches.
    function logSessions(entry) {
        return [entry.node, entry.from, entry.decision?.node].filter((node, i, all) => node && all.indexOf(node) === i);
    }

    // What an entry names, which Enter opens: its decision, else the desk for
    // a tell, else its session while it is in the fleet, as { key, text,
    // item }, `item` being what the panel holds once the key's row is gone.
    function logLink(entry) {
        if (!knows(entry))
            return null;
        if (entry.decision)
            return {
                key: `decision:${entry.decision.id}`,
                text: `Decision ${entry.decision.id}`,
                item: entry.decision
            };
        if (entry.kind === "tell" || entry.node === "desk")
            return {
                key: "desk",
                text: "Desk",
                item: null
            };
        return sessionLink(entry.node);
    }

    // A session's link, while it is in the fleet.
    function sessionLink(node) {
        if (!node || !Bosun.sessions.some(s => s.node === node))
            return null;
        return {
            key: `session:${node}`,
            text: `Open ${node}`,
            item: null
        };
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
