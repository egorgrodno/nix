import QtQuick

// A PNG of the first row of each entry kind in the conversation, at the top
// of the view, as `<pane>-kind-<kind>.png` in `SNAPS` (run's `-o`). The
// desk's first master answer is open.
QtObject {
    property var kinds: []
    property int frames: 3

    function setup(h) {
        const seen = new Set();
        for (const row of h.conv.rows)
            if (!seen.has(row.kind))
                seen.add(row.kind);
        kinds = [...seen];
        // The master's answer on the desk opens at a click, and shows its text then.
        const answer = h.rowIndex(row => row.kind === "desk-master");
        if (answer >= 0)
            h.conv.toggle(h.conv.rows[answer].id);
        frames = 3 * kinds.length;
    }

    // Moves to the row on one frame and snaps it on the next, which renders
    // a frame later.
    function step(h, f) {
        const kind = kinds[Math.floor(f / 3)];
        if (f % 3 === 0)
            h.show(h.rowIndex(row => row.kind === kind));
        else if (f % 3 === 1)
            h.snap(`kind-${kind}`);
    }
}
