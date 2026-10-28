import QtQuick

// The full panel with its sidebar collapsed to the rail: every tile, the
// sessions' among them, as wide as the rest and centred in the rail. Runs on
// the session pane only.
QtObject {
    property int frames: 3
    property var view: null
    property var kept: ({})

    function setup(h) {
        if (h.pane !== "session")
            return;
        kept = {
            sidebarOpen: BosunKept.sidebarOpen,
            selected: BosunKept.selected
        };
        BosunKept.sidebarOpen = false;
        BosunKept.select(`session:${Bosun.tree[0].node}`);
        view = Qt.createQmlObject("import QtQuick\nBosunView { z: 10; width: 1400; height: 780 }", h.conv.parent, Qt.resolvedUrl("scn-rail.qml"));
    }

    function step(h, f) {
        if (!view)
            return false;
        if (f !== 2)
            return;
        let rail = null;
        h.walk(view, it => {
            if (!rail && it.picked !== undefined && it.now !== undefined && it.visible)
                rail = it;
        });
        const tiles = [];
        h.walk(rail, it => {
            if (it.tipContent !== undefined && it.visible && !tiles.includes(it))
                tiles.push(it);
        });
        const centre = rail.width / 2;
        const off = tiles.filter(t => Math.abs(t.mapToItem(rail, 0, 0).x + t.width / 2 - centre) > 0.5 || t.width !== tiles[0].width);
        const sessions = tiles.filter(t => t.label !== "").length;
        h.note(`${off.length === 0 && sessions > 0 ? "PASS" : "FAIL"} ${tiles.length} tiles, ${sessions} of sessions, centred at ${centre} and ${tiles[0].width} wide: ${off.map(t => `${t.label || t.glyph} at ${t.mapToItem(rail, 0, 0).x}, ${t.width} wide`).join("; ") || "all"}`);
    }

    function finish() {
        view?.destroy();
        BosunKept.sidebarOpen = kept.sidebarOpen ?? true;
        if (kept.selected)
            BosunKept.select(kept.selected);
    }
}
