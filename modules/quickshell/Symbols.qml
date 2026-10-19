pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Emoji and Nerd Font glyphs by name, from the symbols.json the module builds
// beside the shell, the last ones copied first.
Singleton {
    id: root

    // { char, name, group, key }, the key the name lowercased.
    readonly property var symbols: {
        try {
            return JSON.parse(data.text()).map(s => ({
                        char: s[0],
                        name: s[1],
                        group: s[2],
                        key: s[1].toLowerCase()
                    }));
        } catch (e) {
            return [];
        }
    }
    readonly property var byChar: new Map(symbols.map(s => [s.char, s]))
    // Characters, the last copied first.
    property var recent: []
    // Rows past this many are never worth scrolling to.
    readonly property int limit: 300

    // Rows for the panel. With no query, the recent symbols, then every one in
    // the data's order, emoji first; with one, those whose name holds every
    // word, best first.
    function search(query) {
        const row = s => ({
                    kind: "symbol",
                    symbol: s
                });
        const words = Launcher.tokens(query);
        if (words.length === 0) {
            const all = symbols.slice(0, limit).map(row);
            const last = recent.map(c => byChar.get(c)).filter(s => s !== undefined).map(row);
            if (last.length === 0)
                return all;
            return [
                {
                    kind: "header",
                    title: "Recent"
                },
                ...last,
                {
                    kind: "header",
                    title: "All"
                },
                ...all];
        }
        const ranked = [];
        for (const s of symbols) {
            let total = 0;
            for (const word of words) {
                const best = Launcher.score(word, s.key, false);
                if (best === 0) {
                    total = 0;
                    break;
                }
                total += best;
            }
            if (total > 0)
                ranked.push({
                    symbol: s,
                    score: total
                });
        }
        return ranked.sort((a, b) => b.score - a.score).slice(0, limit).map(r => row(r.symbol));
    }

    function copy(symbol) {
        Quickshell.execDetached([Programs.wlCopy, "--", symbol.char]);
        recent = [symbol.char, ...recent.filter(c => c !== symbol.char)].slice(0, 20);
        storage.setText(JSON.stringify({
            recent: recent
        }));
    }

    FileView {
        id: data

        path: Quickshell.shellPath("symbols.json")
        blockAllReads: true
    }

    FileView {
        id: storage

        path: Quickshell.statePath("launcher/symbols.json")
        blockAllReads: true
        printErrors: false
    }

    Component.onCompleted: {
        try {
            recent = JSON.parse(storage.text()).recent ?? [];
        } catch (e) {}
    }
}
