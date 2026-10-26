pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// A session's conversation as `bosun follow` sends it: a reset, the latest
// entries, then each new one and the turn in progress. `bosun conversation`
// fetches older ones on demand. An entry sent again under its id, as a tool
// call is once its result lands, replaces the one before.
Item {
    id: feed

    // The session's node; empty follows nothing.
    property string node
    // Oldest first.
    property var entries: []
    // The turn in progress: `tempo`, `state`, `detail` and `needs`, all empty
    // once the session's process ends; null before the first.
    property var progress: null
    // Whether entries older than the first exist.
    property bool more: false
    readonly property bool loadingOlder: older.running
    // How many entries each request asks for, meta entries uncounted.
    property int page: 100

    // Off stops following and keeps the entries held.
    property bool live: true

    // Each id's place in `entries`.
    property var places: ({})
    // Set by a reset: the entries line after it is the latest page, with
    // `more`.
    property bool opening: false

    // Around putting older entries at the start, for a view to keep its place.
    signal prepending
    signal prepended

    function clear() {
        entries = [];
        places = {};
        progress = null;
        more = false;
    }

    // Merges `list` into `entries`, replacing an entry whose id is there
    // already, and putting the new ones at the start when `before` is set.
    function merge(list, before) {
        const replaced = [...entries];
        const fresh = [];
        for (const entry of list) {
            const at = places[entry.id];
            if (at !== undefined)
                replaced[at] = entry;
            else
                fresh.push(entry);
        }
        const all = before ? fresh.concat(replaced) : replaced.concat(fresh);
        const map = {};
        all.forEach((entry, i) => map[entry.id] = i);
        places = map;
        entries = all;
    }

    function loadOlder() {
        if (!more || older.running || entries.length === 0)
            return;
        older.command = [Programs.bosun, "conversation", "-before", entries[0].id, "-limit", String(page), node];
        older.running = true;
    }

    function receive(line) {
        let message;
        try {
            message = JSON.parse(line);
        } catch (e) {
            return;
        }
        switch (message.type) {
        case "reset":
            clear();
            older.running = false;
            opening = true;
            break;
        case "entries":
            merge(message.entries ?? [], false);
            if (opening)
                more = message.more === true;
            opening = false;
            break;
        case "progress":
            progress = message;
            break;
        }
    }

    function restart() {
        clear();
        follow.running = false;
        older.running = false;
        retry.stop();
        if (node === "" || !live)
            return;
        follow.command = [Programs.bosun, "follow", "-limit", String(page), node];
        follow.running = true;
    }

    onNodeChanged: restart()
    onLiveChanged: {
        if (live)
            restart();
        else {
            follow.running = false;
            retry.stop();
        }
    }
    Component.onCompleted: restart()

    Process {
        id: follow

        stdout: SplitParser {
            onRead: line => feed.receive(line)
        }
        onExited: {
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
                if (result.error)
                    return;
                feed.prepending();
                feed.merge(result.entries ?? [], true);
                feed.more = result.more === true;
                feed.prepended();
            }
        }
    }

    // `follow` ends with the daemon, and starts again a few seconds later.
    Timer {
        id: retry

        interval: 5000
        onTriggered: feed.restart()
    }
}
