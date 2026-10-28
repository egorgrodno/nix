import QtQuick

// The full panel's and the overview's keys, which no compositor here hands
// the panel: each builds over the stage and takes events through its own
// `press`, and a PASS or FAIL note says what each key did. Runs on the
// session pane only.
QtObject {
    property int frames: 11
    property var view: null
    property var overview: null
    property var kept: ({})
    property var tell: null
    property string tellKept

    function key(code, text) {
        return {
            key: code ?? 0,
            text: text ?? "",
            modifiers: Qt.NoModifier,
            matches: () => false
        };
    }

    function check(h, ok, what) {
        h.note(`${ok ? "PASS" : "FAIL"} ${what}`);
    }

    function setup(h) {
        if (h.pane !== "session")
            return;
        kept = {
            full: BosunKept.full,
            sidebarOpen: BosunKept.sidebarOpen,
            selected: BosunKept.selected
        };
        view = Qt.createQmlObject("import QtQuick\nBosunView { z: 10; width: 1400; height: 780 }", h.conv.parent, Qt.resolvedUrl("scn-keys.qml"));
    }

    function step(h, f) {
        if (!view)
            return false;
        switch (f) {
        case 0:
            BosunKept.sidebarOpen = true;
            BosunKept.select("desk");
            view.focusAt("list");
            view.press(key(0, "["));
            check(h, !BosunKept.sidebarOpen, "[ collapses the sidebar");
            break;
        case 2:
            check(h, view.focusName() === "rail", `the rail takes the keyboard, found ${view.focusName()}`);
            view.press(key(0, "["));
            check(h, BosunKept.sidebarOpen, "[ opens the sidebar");
            break;
        case 4:
            check(h, view.focusName() === "sidebar", `the sidebar takes the keyboard back, found ${view.focusName()}`);
            BosunKept.select(`log:${Bosun.log[Bosun.log.length - 1].seq}`);
            view.focusPane();
            check(h, view.press(key(Qt.Key_Escape)) && view.focusName() === "table", `Esc in the pane goes back to the list, found ${view.focusName()}`);
            check(h, !view.press(key(Qt.Key_Escape)), "Esc in the list goes on to close the panel");
            view.press(key(0, "/"));
            check(h, view.focusName() === "field", `/ takes the Log's filter, found ${view.focusName()}`);
            view.focusAt("list");
            view.press(key(0, "f"));
            check(h, !BosunKept.full, "f switches to the overview");
            BosunKept.full = true;
            break;
        case 6:
            overview = Qt.createQmlObject("import QtQuick\nBosunOverview { z: 11; width: 440 }", h.conv.parent, Qt.resolvedUrl("scn-keys.qml"));
            overview.forceActiveFocus();
            overview.press(key(Qt.Key_Tab));
            check(h, overview.inRows && overview.current === `decision:${Bosun.mine[0].id}`, `Tab takes the overview's rows, on ${overview.current}`);
            overview.press(key(Qt.Key_Down));
            check(h, overview.current === `session:${Bosun.tree[0].node}`, `the movement keys move through them, on ${overview.current}`);
            overview.press(key(Qt.Key_Tab));
            check(h, overview.panelState().focus === "field", `Tab goes on to the field, found ${overview.panelState().focus}`);
            overview.forceActiveFocus();
            overview.press(key(0, "f"));
            check(h, BosunKept.full, "f in the overview opens the full panel");
            break;
        // The overview's field: Up and Down that its TextEdit passes on at
        // its first or last line stay in it, and a long line wraps clear of
        // the send glyph as the field grows.
        case 7:
            h.walk(overview, it => {
                if (it.draftKey === "tell")
                    tell = it;
            });
            tellKept = tell.text;
            tell.focusIn();
            overview.focusRows();
            overview.press(key(Qt.Key_Down));
            const on = overview.current;
            tell.focusIn();
            check(h, tell.press?.(key(Qt.Key_Down)) === true && tell.press(key(Qt.Key_Up)) === true && overview.current === on, `Up and Down stay in the overview's field, on ${overview.current}`);
            tell.text = "A line to the desk long enough to wrap twice in the overview's field, past where the send glyph sits at its right, and on.";
            break;
        case 9:
            let input = null;
            let glyph = null;
            h.walk(tell, it => {
                if (it.cursorPosition !== undefined)
                    input = it;
                else if (it.text === BosunLook.send)
                    glyph = it;
            });
            const right = input.mapToItem(tell, input.width, 0).x;
            check(h, tell.height > 40 && right <= glyph.x, `a long line wraps clear of the send glyph: ${Math.round(tell.height)} tall, text to ${Math.round(right)}, glyph at ${Math.round(glyph.x)}`);
            tell.text = tellKept;
            break;
        }
    }

    function finish() {
        overview?.destroy();
        view?.destroy();
        BosunKept.full = kept.full ?? true;
        BosunKept.sidebarOpen = kept.sidebarOpen ?? true;
        if (kept.selected)
            BosunKept.select(kept.selected);
    }
}
