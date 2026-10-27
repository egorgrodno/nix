pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// A session's conversation as `bosun follow` sends it: a reset, the latest
// entries, then each new one and the turn in progress. `bosun conversation`
// fetches older ones on demand. An entry sent again under its id, as a tool
// call is once its result lands, replaces the one before.
//
// Only another node starts it afresh. A reconnect, or a reset to the same
// conversation, merges its first page into the entries held. A new
// conversation goes below the old one's entries after a `cleared` entry,
// unless it copies them, as a resume does, and then it merges too.
Item {
    id: feed

    // The session's node; empty follows nothing.
    property string node
    // Oldest first.
    property var entries: []
    // The turn in progress: `tempo`, `state`, `detail` and `needs`, all empty
    // once the session's process ends; null before the first.
    property var progress: null
    // Whether entries older than the current conversation's first exist.
    property bool more: false
    readonly property bool loadingOlder: older.running
    // How many entries each request asks for, meta entries uncounted.
    property int page: 100

    // Off stops following and keeps the entries held.
    property bool live: true

    // Each id's place in `entries`.
    property var places: ({})
    // From a start with nothing held until the latest page, with `more`.
    property bool opening: false
    // The session id of the conversation the entries held end with.
    property string session: ""
    // The `cleared` entry the current conversation's entries follow, if any.
    property string divider: ""
    // The session id of the latest reset, whose page comes next.
    property string resetTo: ""
    // Set when `follow` is stopped for a restart, so that its end starts no
    // retry: Quickshell ends the old process only after `running` turns true
    // again.
    property bool stopping: false
    // Whether the running `follow` has sent anything.
    property bool heard: false

    // Around putting older entries at the start, for a view to keep its place.
    signal prepending
    signal prepended
    // The latest page has come, after a start with nothing held.
    signal opened

    function clear() {
        entries = [];
        places = {};
        progress = null;
        more = false;
        session = "";
        divider = "";
    }

    // `L<line>` ids repeat from one transcript to the next, so they carry
    // their session's.
    function keyed(entry, sid) {
        return entry.id.startsWith("L") ? Object.assign({}, entry, {
            id: `${sid}/${entry.id}`
        }) : entry;
    }

    function daemonId(id) {
        return id.slice(id.indexOf("/") + 1);
    }

    // Merges `list` into `entries`: an entry whose id is there already
    // replaces it if it changed, and a new one goes beside its neighbours in
    // `list`. With none held, the new ones go at the current conversation's
    // start when `before` is set, else at the end.
    function merge(list, before) {
        const rows = [...entries];
        const ahead = {};
        const behind = {};
        let pending = [];
        let last = -1;
        for (const entry of list) {
            const at = places[entry.id];
            if (at === undefined) {
                pending.push(entry);
                continue;
            }
            // A page sent again after a reconnect holds every entry anew, and
            // an object that differs refreshes its row though nothing changed.
            if (JSON.stringify(rows[at]) !== JSON.stringify(entry))
                rows[at] = entry;
            if (pending.length > 0) {
                if (last < 0)
                    ahead[at] = pending;
                else
                    behind[last] = (behind[last] ?? []).concat(pending);
                pending = [];
            }
            last = at;
        }
        let start = [];
        let end = [];
        if (pending.length > 0) {
            if (last >= 0)
                behind[last] = (behind[last] ?? []).concat(pending);
            else if (before && divider !== "")
                behind[places[divider]] = pending;
            else if (before)
                start = pending;
            else
                end = pending;
        }
        const all = [...start];
        rows.forEach((row, i) => all.push(...(ahead[i] ?? []), row, ...(behind[i] ?? [])));
        all.push(...end);
        const map = {};
        all.forEach((entry, i) => map[entry.id] = i);
        places = map;
        entries = all;
    }

    // A reset's page, into what is held.
    function receivePage(message) {
        const sid = resetTo;
        const list = (message.entries ?? []).map(e => keyed(e, sid));
        const fresh = entries.length === 0;
        const held = list.some(e => places[e.id] !== undefined);
        // A page that shares nothing with the entries held and has more
        // before it leaves a gap between them.
        if (fresh || !held && message.more === true) {
            const turn = progress;
            clear();
            progress = turn;
            opening = true;
            session = sid;
            merge(list, false);
            more = message.more === true;
            opening = false;
            opened();
            return;
        }
        if (sid !== session && !held) {
            // The old conversation's older entries are no longer the
            // session's to fetch.
            const cleared = {
                id: `cleared:${sid}`,
                kind: "cleared",
                at: list[0]?.at ?? new Date().toISOString()
            };
            divider = cleared.id;
            more = false;
            merge([cleared, ...list], false);
        } else {
            merge(list, false);
        }
        session = sid;
    }

    function loadOlder() {
        const first = divider !== "" ? places[divider] + 1 : 0;
        if (!more || older.running || first >= entries.length)
            return;
        older.command = [Programs.bosun, "conversation", "-before", daemonId(entries[first].id), "-limit", String(page), node];
        older.running = true;
    }

    function receive(line) {
        // The rest of a stopped process's output, which may be another node's.
        if (stopping)
            return;
        let message;
        try {
            message = JSON.parse(line);
        } catch (e) {
            return;
        }
        heard = true;
        switch (message.type) {
        case "reset":
            resetTo = message.session ?? "";
            if (entries.length === 0)
                opening = true;
            older.running = false;
            break;
        case "entries":
            if (resetTo !== "") {
                receivePage(message);
                resetTo = "";
            } else
                merge((message.entries ?? []).map(e => keyed(e, session)), false);
            break;
        case "progress":
            progress = message;
            break;
        }
    }

    // Keeps the entries held, for the next page to merge into.
    function connect() {
        retry.stop();
        older.running = false;
        resetTo = "";
        if (follow.running) {
            stopping = true;
            follow.running = false;
        }
        if (node === "" || !live)
            return;
        heard = false;
        follow.command = [Programs.bosun, "follow", "-limit", String(page), node];
        follow.running = true;
    }

    onNodeChanged: {
        clear();
        connect();
    }
    onLiveChanged: {
        if (live)
            connect();
        else {
            stopping = follow.running;
            follow.running = false;
            retry.stop();
        }
    }
    Component.onCompleted: connect()

    Process {
        id: follow

        stdout: SplitParser {
            onRead: line => feed.receive(line)
        }
        // Rather than `exited`, which a process that fails to start never
        // sends.
        onRunningChanged: {
            if (running)
                return;
            if (feed.stopping) {
                feed.stopping = false;
                return;
            }
            // Kept through one reconnect, and dropped once one fails.
            if (!feed.heard)
                feed.progress = null;
            if (feed.node !== "" && feed.live)
                retry.start();
        }
    }

    Process {
        id: older

        stdout: StdioCollector {
            onStreamFinished: {
                let result;
                try {
                    result = JSON.parse(text);
                } catch (e) {
                    return;
                }
                if (result.error || result.session !== feed.session)
                    return;
                feed.prepending();
                feed.merge((result.entries ?? []).map(e => feed.keyed(e, feed.session)), true);
                feed.more = result.more === true;
                feed.prepended();
            }
        }
    }

    // `follow` ends with the daemon, and starts again a few seconds later.
    Timer {
        id: retry

        interval: 5000
        onTriggered: feed.connect()
    }
}
