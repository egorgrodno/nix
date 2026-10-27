pragma Singleton

import QtQuick
import Quickshell

// The front desk's conversation as the panel reads it from `bosun follow
// desk` and the fleet's log: the user's messages, the desk's answers, each
// instruction it passed to the master with what became of it, and each
// decision it answered on the user's word.
Singleton {
    id: root

    // The heads `deskReport` in bosun's daemon.go puts on each tell it hands
    // the desk; they must match it.
    readonly property string userHead: "bosun: the user sent this through bosun tell, so they may not be watching this session:\n"
    readonly property string masterHead: "bosun: the master answers:\n"
    readonly property string againHead: "bosun: a turn of yours that took this was cut short, so you may have acted on it already.\n"

    // A prompt bosun handed the desk, split into the user's tells and the
    // master's answers, as { from: "user" | "master" | "bosun", text }; null
    // for any other text.
    function reportParts(text) {
        if (![userHead, masterHead, againHead].some(head => text.startsWith(head)))
            return null;
        return text.split(/\n\n(?=bosun: (?:the user sent this through bosun tell|the master answers:|a turn of yours that took this))/).map(chunk => {
            const part = chunk.startsWith(againHead) ? chunk.slice(againHead.length) : chunk;
            if (part.startsWith(userHead))
                return {
                    from: "user",
                    text: part.slice(userHead.length)
                };
            if (part.startsWith(masterHead))
                return {
                    from: "master",
                    text: part.slice(masterHead.length)
                };
            return {
                from: "bosun",
                text: part
            };
        });
    }

    // What a tell handed at the desk's Stop says: the transcript keeps it
    // only in a hook's blocking error, which the feed sends as meta.
    function blockedReport(entry) {
        const attachment = entry.raw?.attachment;
        if (entry.recordType !== "attachment/hook_blocking_error" || attachment?.hookEvent !== "Stop")
            return "";
        const text = attachment.blockingError?.blockingError ?? "";
        return typeof text === "string" ? text : "";
    }

    // The log's `tell` entries to the desk from `by`, "user" or "master".
    function tellsToDesk(by) {
        return Bosun.log.filter(e => e.kind === "tell" && e.by === by && e.node === "desk");
    }

    // The daemon cuts a meta entry's strings to 2000 characters and "…"; the
    // log holds the tell whole.
    function whole(text, by) {
        if (!text.endsWith("…"))
            return text;
        const start = text.slice(0, -1);
        return tellsToDesk(by).find(e => (e.text ?? "").startsWith(start))?.text ?? text;
    }

    // The feed's entries as the desk pane shows them, oldest first. The kinds
    // the panel adds begin with "desk-": `desk-you` for the user's message,
    // `desk-master` for the master's answer, `desk-text` for the desk's own,
    // `desk-instruction` for a tell_master call, `desk-answered` for an answer
    // given on the user's word, and `desk-pending` for a tell the desk has not
    // taken yet. The desk's lookups of its own tools are left out.
    function shape(entries) {
        const out = [];
        let instructions = 0;
        let lastReport = "";
        const putParts = (entry, text) => {
            const parts = reportParts(text);
            if (!parts)
                return false;
            lastReport = entry.at ?? lastReport;
            parts.forEach((part, i) => {
                const id = `${entry.id}/${i}`;
                if (part.from === "user")
                    out.push({
                        id: id,
                        kind: "desk-you",
                        at: entry.at,
                        text: whole(part.text, "user"),
                        told: true
                    });
                else if (part.from === "master")
                    out.push({
                        id: id,
                        kind: "desk-master",
                        at: entry.at,
                        text: whole(part.text, "master")
                    });
                else
                    out.push(Object.assign({}, entry, {
                        id: id,
                        text: part.text
                    }));
            });
            return true;
        };
        for (const entry of entries) {
            switch (entry.kind) {
            case "prompt":
                if (entry.from === "user")
                    out.push(Object.assign({}, entry, {
                        kind: "desk-you"
                    }));
                else if (entry.from !== "bosun" || !putParts(entry, entry.text ?? ""))
                    out.push(entry);
                continue;
            case "meta":
                {
                    const text = blockedReport(entry);
                    if (text === "" || !putParts(entry, text))
                        out.push(entry);
                    continue;
                }
            case "text":
                out.push(Object.assign({}, entry, {
                    kind: "desk-text"
                }));
                continue;
            case "tool":
                if (entry.name === "ToolSearch")
                    continue;
                if (entry.name === "mcp__bosun__tell_master") {
                    out.push(Object.assign({}, entry, {
                        kind: "desk-instruction",
                        number: ++instructions
                    }));
                    continue;
                }
                if (entry.name === "mcp__bosun__answer" && entry.input?.words && entry.result && !entry.result.error) {
                    out.push(Object.assign({}, entry, {
                        kind: "desk-answered"
                    }));
                    continue;
                }
            }
            out.push(entry);
        }
        return out.concat(pending(entries, out, lastReport));
    }

    // The user's tells the desk has not taken: those in the log since the
    // last tell it took, or since the conversation's first entry, that no
    // message shows.
    function pending(entries, shaped, lastReport) {
        if (entries.length === 0)
            return [];
        const since = new Date(lastReport || (entries[0]?.at ?? 0)).getTime();
        const shown = new Set(shaped.filter(e => e.kind === "desk-you" && e.told).map(e => e.text));
        return tellsToDesk("user").filter(e => new Date(e.at).getTime() >= since && !shown.has(e.text)).map(e => ({
                    id: `pending:${e.seq}`,
                    kind: "desk-pending",
                    at: e.at,
                    text: e.text
                }));
    }

    // What became of an instruction the desk passed to the master: the
    // log's `tell` that carried it, the master's spawned, resumed and merged
    // entries, and its answers to the desk. Nothing links them in the
    // daemon, so each takes what the master did between this instruction and
    // the desk's next; two instructions in flight at once mix theirs.
    function outcome(text, at) {
        const tells = Bosun.log.filter(e => e.kind === "tell" && e.by === "desk" && e.node === "master");
        const when = new Date(at ?? 0).getTime();
        let i = -1;
        tells.forEach((e, j) => {
            if (e.text === text && (i < 0 || Math.abs(new Date(e.at).getTime() - when) < Math.abs(new Date(tells[i].at).getTime() - when)))
                i = j;
        });
        if (i < 0)
            return null;
        const from = tells[i].seq;
        const to = i + 1 < tells.length ? tells[i + 1].seq : Infinity;
        const after = Bosun.log.filter(e => e.seq > from && e.seq < to && e.by === "master");
        return {
            tell: tells[i],
            acts: after.filter(e => ["spawned", "resumed", "merged"].includes(e.kind)),
            answers: after.filter(e => e.kind === "tell" && e.node === "desk")
        };
    }

    // The decisions and sessions a text names, which open in the panel, as
    // { key, text, item } like `BosunLook.logLink`. A decision counts once the
    // panel knows it: waiting, answered on the user's word, or in the log.
    function links(text) {
        const found = [];
        const seen = new Set();
        // QML's JavaScript has no String.matchAll.
        const named = /\bdecision\s+#?(\d+)/gi;
        for (let match = named.exec(text); match; match = named.exec(text)) {
            const id = match[1];
            if (seen.has(`decision:${id}`))
                continue;
            const decision = Bosun.decisions.find(d => d.id === id) ?? Bosun.answered.find(a => a.decision?.id === id)?.decision ?? [...Bosun.log].reverse().find(e => e.decision?.id === id)?.decision;
            if (!decision)
                continue;
            seen.add(`decision:${id}`);
            found.push({
                key: `decision:${id}`,
                text: `Open decision ${id}`,
                item: decision
            });
        }
        for (const session of Bosun.sessions) {
            const node = session.node;
            // The desk speaks of the master in nearly every answer.
            if (["desk", "master"].includes(node) || seen.has(`session:${node}`))
                continue;
            const escaped = node.replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
            if (!new RegExp(`(^|[^\\w-])${escaped}([^\\w-]|$)`).test(text))
                continue;
            seen.add(`session:${node}`);
            found.push(BosunLook.sessionLink(node));
        }
        return found.slice(0, 6);
    }
}
