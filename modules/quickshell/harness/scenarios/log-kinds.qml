import QtQuick

// Checks that the fake log holds an entry of every kind the Log knows, and
// that none shows as one bosun cannot show. A failure is a `FAIL` note, which
// run.sh leaves in its output.
QtObject {
    property int frames: 1

    function step(h, f) {
        if (h.pane !== "session")
            return false;
        const kinds = new Set(Bosun.log.map(e => e.kind));
        const missing = BosunLook.logKinds.filter(k => !kinds.has(k));
        const raw = Bosun.log.filter(e => !BosunLook.knows(e)).map(e => e.kind);
        const blank = Bosun.log.filter(e => BosunLook.logTitle(e) === "" || BosunLook.logWhat(e) === "").map(e => e.kind);
        h.note(`${kinds.size} kinds of ${BosunLook.logKinds.length}${missing.length ? `, FAIL missing ${missing}` : ""}${raw.length ? `, FAIL raw ${raw}` : ""}${blank.length ? `, FAIL blank ${blank}` : ""}${missing.length + raw.length + blank.length === 0 ? ", every one known" : ""}`);
    }
}
