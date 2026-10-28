import QtQuick

// The selected row's edge in the sidebar and the selected tile's in the rail,
// with the keyboard in the list and in the pane's composer: blue in the list,
// a fainter blue elsewhere, never gone into the fill. Runs on the session
// pane only.
QtObject {
    property int frames: 6
    property var view: null
    property var kept: ({})

    function setup(h) {
        if (h.pane !== "session")
            return;
        kept = {
            sidebarOpen: BosunKept.sidebarOpen,
            selected: BosunKept.selected
        };
        BosunKept.sidebarOpen = true;
        BosunKept.select("desk");
        view = Qt.createQmlObject("import QtQuick\nBosunView { z: 10; width: 1400; height: 780 }", h.conv.parent, Qt.resolvedUrl("scn-edge.qml"));
    }

    // The 2 px edge of the selected row that shows.
    function edge(h) {
        let found = null;
        h.walk(view, it => {
            if (!found && it.current === true && it.edgeOffset !== undefined && it.visible && it.width > 0)
                for (const fill of it.children)
                    for (const c of fill.children ?? [])
                        if (c.width === 2 && c.visible)
                            found = c;
        });
        return found;
    }

    function check(h, where) {
        const e = edge(h);
        const c = e?.color;
        // Blue over the fill: the blue channel well over the red, and opaque
        // enough to show.
        const ok = c !== undefined && c.b - c.r > 0.2 && c.a >= 0.3;
        h.note(`${ok ? "PASS" : "FAIL"} the edge with the keyboard ${where} (${view.focusName()}): ${c ?? "none"}`);
    }

    function step(h, f) {
        if (!view)
            return false;
        switch (f) {
        case 0:
            view.focusAt("list");
            break;
        case 1:
            check(h, "in the sidebar");
            view.focusPane();
            break;
        case 2:
            check(h, "in the composer, sidebar open");
            BosunKept.sidebarOpen = false;
            view.focusAt("list");
            break;
        case 3:
            check(h, "in the rail");
            view.focusPane();
            break;
        case 4:
            check(h, "in the composer, rail");
            break;
        }
    }

    function finish() {
        view?.destroy();
        BosunKept.sidebarOpen = kept.sidebarOpen ?? true;
        if (kept.selected)
            BosunKept.select(kept.selected);
    }
}
