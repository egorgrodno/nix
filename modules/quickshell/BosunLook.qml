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
    readonly property string cancel: "\u{F073A}"
    readonly property string chevronRight: "\u{F0142}"
    readonly property string message: "\u{F12F5}"
    readonly property string running: "\u{F0772}"
    readonly property string interrupt: "\u{F04DB}"
    readonly property string thinking: "\u{F07F7}"
    readonly property string compacted: "\u{F084D}"
    readonly property string command: "\u{F0FDF}"
    readonly property string queued: "\u{F011D}"
    readonly property string eye: "\u{F06D0}"

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
    // own prompt. One an open decision names is blocked too, whoever holds
    // it, though Claude Code calls it busy.
    function stateOf(session) {
        if (session.killed)
            return "killed";
        if (session.paused)
            return "paused";
        if (session.limitedUntil)
            return "limited";
        if (Bosun.decisions.some(d => d.node === session.node))
            return "blocked";
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
        const kind = Bosun.kindOf(decision);
        if (kind === "question")
            return "\u{F0625}";
        if (kind === "notice")
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
        if (activity.tool?.startsWith("mcp__"))
            return mcpGlyph(activity.tool);
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
        if (activity.tool?.startsWith("mcp__"))
            return mcpWords(activity.tool, activity.arg ?? "");
        return activity.tool ? activity.arg ?? activity.tool : activity.text ?? "";
    }

    // Whether the activity line shows a call in monospace: a tool's argument,
    // but not the words an MCP call reads as.
    function activityMono(activity) {
        return !!activity?.tool && !activity.tool.startsWith("mcp__");
    }

    // An MCP tool's name as { server, tool }: "mcp__bosun__decide" is bosun's
    // decide.
    function mcpParts(name) {
        const parts = name.split("__");
        return {
            server: parts[1] ?? "",
            tool: parts.slice(2).join("__")
        };
    }

    function mcpGlyph(name) {
        const call = mcpParts(name);
        if (call.server !== "bosun")
            return "\u{F1425}";
        return {
            next_event: "\u{F02FB}",
            status: eye,
            transcript: "\u{F09ED}",
            decide: "\u{F05D1}",
            reply: "\u{F045A}",
            answer: "\u{F045A}",
            escalate: "\u{F0B54}",
            spawn: "\u{F0419}",
            resume: "\u{F040D}",
            merge: "\u{F062D}",
            ask: "\u{F0625}",
            tell_master: master,
            tell_desk: desk,
            notify: "\u{F009C}"
        }[call.tool] ?? "\u{F1064}";
    }

    // What an MCP call does, from the summary of its input that the daemon
    // puts in an activity's `arg`: "Deciding 147: allow", "Spawning app-flaky",
    // or another server's tool and its argument, as "craft docs
    // create_document: Notes".
    function mcpWords(name, arg) {
        const call = mcpParts(name);
        const after = text => text ? `: ${text}` : "";
        if (call.server !== "bosun")
            return `${call.server.replace(/_/g, " ")} ${call.tool}${after(arg)}`;
        const words = arg.split(" ");
        switch (call.tool) {
        case "next_event":
            return "Waiting for events";
        case "status":
            return "Reading the fleet";
        case "transcript":
            return `Reading ${arg}'s transcript`;
        case "decide":
            return `Deciding ${words[0]}${after(words.slice(1).join(" "))}`;
        case "reply":
            return `Answering ${arg}`;
        case "answer":
            return `Answering ${arg} on the user's word`;
        case "escalate":
            return `Passing ${arg} to the user`;
        case "spawn":
            return `Spawning ${arg}`;
        case "resume":
            return `Resuming ${arg}`;
        case "merge":
            return `Merging ${arg}`;
        case "ask":
            return `Asking${after(arg)}`;
        case "tell_master":
            return `Telling the master${after(arg)}`;
        case "tell_desk":
            return `Telling the desk${after(arg)}`;
        case "notify":
            return `Telling the user${after(arg)}`;
        }
        return `bosun ${call.tool}${after(arg)}`;
    }

    // The `arg` the daemon gives an MCP call's activity, read from the call's
    // input as bosun's activity.go does, for a conversation's tool rows.
    function mcpArg(name, input) {
        const call = mcpParts(name);
        const line = value => typeof value === "string" ? value.replace(/\s+/g, " ").trim() : "";
        const fields = input ?? {};
        if (call.server !== "bosun")
            return line(Object.values(fields).find(value => typeof value === "string" && value.trim() !== ""));
        switch (call.tool) {
        case "decide":
            return `${fields.id ?? ""} ${fields.allow === true ? "allow" : "deny"}`;
        case "spawn":
        case "resume":
        case "merge":
        case "transcript":
            return line(fields.name);
        case "reply":
        case "escalate":
        case "answer":
            return line(fields.id);
        case "tell_desk":
        case "tell_master":
            return line(fields.text);
        case "notify":
            return line(fields.message);
        case "ask":
            return line(fields.question);
        }
        return "";
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
    readonly property var logKinds: ["decision", "escalated", "settled", "tell", "message", "spawned", "resumed", "merged", "killed", "paused", "unpaused", "model", "turn_end", "exit", "say", "interrupt", "prompt"]

    function knows(entry) {
        return logKinds.includes(entry.kind) && (!["decision", "escalated", "settled"].includes(entry.kind) || entry.decision);
    }

    // How a settled entry's decision went: "allowed", "denied", "answered",
    // "dismissed" or "withdrawn".
    function outcomeOf(entry) {
        if (entry.withdrawn)
            return "withdrawn";
        if (entry.decision?.kind === "notice" && !entry.behavior)
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
        case "say":
            return `${who} said to ${entry.node}`;
        case "interrupt":
            return `${who} interrupted ${entry.node}`;
        case "prompt":
            return `${who} ${entry.behavior === "deny" ? "denied" : "approved"} ${entry.node}'s own permission prompt`;
        }
        return `${entry.node} stopped`;
    }

    // What follows the title on the entry's line: its text, or what its
    // decision asks.
    function logDetail(entry) {
        if (!knows(entry))
            return entry.kind ?? "";
        // An action of the user's that failed.
        if (entry.error)
            return `failed: ${entry.error}`;
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
        if (!knows(entry) || entry.error)
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
        case "say":
        case "message":
            return "\u{F12F5}";
        case "interrupt":
            return interrupt;
        case "prompt":
            return entry.behavior === "deny" ? "\u{F015A}" : "\u{F05E1}";
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
        if (entry.error)
            return Theme.red;
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
        case "prompt":
            return entry.behavior === "deny" ? Theme.red : Theme.green;
        case "spawned":
            return Theme.blue;
        case "merged":
            return Theme.magenta;
        case "paused":
            return Theme.yellow;
        }
        return Theme.foregroundMuted;
    }

    // The kinds of conversation entry the panel shows. Any other is one bosun
    // cannot show yet, but for `meta`, the bookkeeping it hides.
    readonly property var entryKinds: ["prompt", "queued", "text", "thinking", "tool", "compact", "command"]

    // Who a prompt came from: the user, bosun, Claude Code, the session's
    // parent, or another session's message.
    function promptTitle(entry, parent) {
        const mid = entry.midTurn ? ", mid-turn" : "";
        switch (entry.from) {
        case "user":
            return `You${mid}`;
        case "bosun":
            return `From bosun${mid}`;
        case "claude":
            return `From Claude Code${mid}`;
        }
        return entry.from === parent ? `Prompt from ${entry.from}${mid}` : `Message from ${entry.from}${mid}`;
    }

    function promptGlyph(entry, parent) {
        switch (entry.from) {
        case "user":
            return account;
        case "bosun":
        case "claude":
            return robot;
        }
        return entry.from === parent ? account : message;
    }

    // What a tool call acts on, on one line, or what an MCP call does.
    function toolArg(entry) {
        if (entry.name?.startsWith("mcp__"))
            return mcpWords(entry.name, mcpArg(entry.name, entry.input));
        const input = entry.input ?? {};
        for (const key of ["command", "file_path", "notebook_path", "pattern", "url", "query", "description", "prompt", "skill"])
            if (typeof input[key] === "string")
                return input[key].split("\n")[0];
        return Object.keys(input).length > 0 ? JSON.stringify(input) : "";
    }

    // The lines a diff's hunks remove and add.
    function diffCounts(hunks) {
        let removed = 0;
        let added = 0;
        for (const hunk of hunks ?? [])
            for (const line of hunk.lines ?? []) {
                if (line.startsWith("-"))
                    removed++;
                else if (line.startsWith("+"))
                    added++;
            }
        return {
            removed: removed,
            added: added
        };
    }

    // "12s", "4 min" or "2 h 5 min".
    function span(ms) {
        const s = Math.max(0, Math.floor(ms / 1000));
        if (s < 60)
            return `${s}s`;
        const m = Math.floor(s / 60);
        if (m < 60)
            return `${m} min`;
        return m % 60 > 0 ? `${Math.floor(m / 60)} h ${m % 60} min` : `${Math.floor(m / 60)} h`;
    }

    // "just now", "4 min ago", "2 h ago", else the date.
    function ago(at, now) {
        if (!at)
            return "";
        const ms = now - new Date(at).getTime();
        if (ms < 60000)
            return "just now";
        if (ms < 86400000)
            return `${span(ms).replace(/ \d+ min$/, "")} ago`;
        return Qt.formatDate(new Date(at), "MMM d");
    }

    // "now", "4m", "2h" or "3d": an age in a sidebar row's right column.
    function age(at, now) {
        if (!at)
            return "";
        const m = Math.floor((now - new Date(at).getTime()) / 60000);
        if (m < 1)
            return "now";
        if (m < 60)
            return `${m}m`;
        return m < 1440 ? `${Math.floor(m / 60)}h` : `${Math.floor(m / 1440)}d`;
    }
}
