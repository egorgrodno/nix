pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The launcher's modes and what they share: the binds that open one, the
// scorer each searches with, and starting a program out of the bar's unit.
// Apps rank by use, each launch's weight halving every two weeks.
Singleton {
    id: root

    readonly property var modes: [
        {
            id: "apps",
            label: "Apps",
            placeholder: "Search apps",
            hint: "Enter launch · Right actions · Tab mode"
        },
        {
            id: "clipboard",
            label: "Clipboard",
            placeholder: "Search the clipboard",
            hint: "Enter copy · Shift Delete forget · Tab mode"
        },
        {
            id: "symbols",
            label: "Symbols",
            placeholder: "Search emoji and glyphs",
            hint: "Enter copy · Tab mode"
        }
    ]
    // Bound from the start: Quickshell scans the entries on first use.
    readonly property var entries: DesktopEntries.applications.values
    readonly property real halfLife: 14 * 24 * 3600
    // By desktop entry id: { weight, time }, the weight as of the time.
    property var usage: ({})

    // The apps module on the focused screen opens its panel in the mode, or
    // closes it there.
    signal toggleRequested(string mode)

    // In a scope of its own: a child of the bar stays in the bar's unit, and
    // restarting the bar would kill it.
    function run(command) {
        Quickshell.execDetached([Programs.uwsm, "app", "--"].concat(command));
    }

    // An app, or one of its actions, through its desktop entry, so uwsm opens
    // a terminal for a terminal app.
    function launch(entry, action) {
        run([`${entry.id}.desktop${action ? ":" + action.id : ""}`]);
        const now = Date.now() / 1000;
        usage = Object.assign({}, usage, {
            [entry.id]: {
                weight: weight(entry.id, now) + 1,
                time: now
            }
        });
        storage.setText(JSON.stringify({
            usage: usage
        }));
    }

    function weight(id, now) {
        const use = usage[id];
        return use ? use.weight * Math.pow(0.5, (now - use.time) / halfLife) : 0;
    }

    // How well a lowercased query token matches a lowercased text, 0 for not at
    // all: a prefix best, then the start of a word in it, then anywhere, then,
    // with `fuzzy`, its letters in order, enough of them starting words or
    // following each other, as "lw" does in "libreoffice writer". Shorter texts
    // and earlier matches rank higher.
    function score(token, text, fuzzy) {
        const i = text.indexOf(token);
        if (i === 0)
            return 1000 - text.length;
        if (i > 0)
            return (wordStart(text, i) ? 800 : 600) - i;
        if (!fuzzy)
            return 0;
        let total = 0;
        let last = -2;
        for (const c of token) {
            const j = text.indexOf(c, last + 1);
            if (j < 0)
                return 0;
            total += (j === last + 1 ? 3 : 1) + (wordStart(text, j) ? 5 : 0);
            last = j;
        }
        return total >= 2.5 * token.length ? total : 0;
    }

    function wordStart(text, i) {
        return i === 0 || " -_.:".includes(text[i - 1]);
    }

    function tokens(query) {
        return query.toLowerCase().split(/\s+/).filter(t => t !== "");
    }

    // Rows for the panel. With no query, the five most used apps, then every
    // app by name; with one, the apps matching each word, best first, use
    // breaking near ties.
    function apps(query) {
        const now = Date.now() / 1000;
        const all = entries;
        const words = tokens(query);
        const row = entry => ({
                    kind: "app",
                    entry: entry,
                    actions: entry.actions
                });
        if (words.length === 0) {
            const byName = [...all].sort((a, b) => a.name.localeCompare(b.name)).map(row);
            const frequent = all.filter(e => weight(e.id, now) > 0).sort((a, b) => weight(b.id, now) - weight(a.id, now)).slice(0, 5).map(row);
            if (frequent.length === 0)
                return byName;
            return [
                {
                    kind: "header",
                    title: "Frequent"
                },
                ...frequent,
                {
                    kind: "header",
                    title: "All apps"
                },
                ...byName];
        }
        const ranked = [];
        for (const entry of all) {
            const name = entry.name.toLowerCase();
            const id = entry.id.toLowerCase();
            const others = [entry.genericName, ...entry.keywords].map(t => t.toLowerCase());
            let total = 0;
            for (const word of words) {
                const best = Math.max(score(word, name, true), score(word, id, true), ...others.map(t => score(word, t, false)));
                if (best === 0) {
                    total = 0;
                    break;
                }
                total += best;
            }
            if (total > 0)
                ranked.push({
                    entry: entry,
                    score: total + 40 * Math.log2(1 + weight(entry.id, now))
                });
        }
        return ranked.sort((a, b) => b.score - a.score || a.entry.name.localeCompare(b.entry.name)).map(r => row(r.entry));
    }

    FileView {
        id: storage

        path: Quickshell.statePath("launcher/apps.json")
        blockAllReads: true
        printErrors: false
    }

    Component.onCompleted: {
        try {
            usage = JSON.parse(storage.text()).usage ?? {};
        } catch (e) {}
    }

    IpcHandler {
        target: "launcher"

        // apps, clipboard or symbols.
        function toggle(mode: string): void {
            if (root.modes.some(m => m.id === mode))
                root.toggleRequested(mode);
        }
    }
}
