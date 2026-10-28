import QtQuick

// A PNG of the live Thinking row and of the live Working row at the end of
// the session pane, as `session-live-thinking.png` and
// `session-live-working.png` in `SNAPS` (run's `-o`), each with the line above
// it for the glyphs to line up against. The desk pane has no such rows.
QtObject {
    property int frames: 14

    // Ends the session's entries on `kind` while it is in its turn.
    function end(h, kind) {
        h.conv.status = "busy";
        h.conv.feed.receive(JSON.stringify({
            type: "entries",
            entries: [h.fake.live(kind)]
        }));
        h.conv.feed.receive(JSON.stringify({
            type: "progress",
            tempo: "working"
        }));
        h.list.positionViewAtEnd();
    }

    function step(h, f) {
        if (h.pane !== "session")
            return false;
        if (f === 0)
            end(h, "thinking");
        if (f === 5)
            h.snap("live-thinking");
        if (f === 6)
            end(h, "prompt");
        if (f === 12)
            h.snap("live-working");
    }
}
