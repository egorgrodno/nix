import QtQuick

// Scrolls every scrolling list in the full panel from top to bottom and notes
// whether its contentHeight holds still on the way: a swing is a ListView
// guessing the height of rows it has not built.
QtObject {
    property int frames: 40
    property var view: null
    property var lists: []
    property var lo: ({})
    property var hi: ({})

    function setup(h) {
        if (h.pane !== "session")
            return;
        BosunKept.sidebarOpen = true;
        view = Qt.createQmlObject("import QtQuick\nBosunView { z: 10; width: 1400; height: 260 }", h.conv.parent, Qt.resolvedUrl("scn-sidebar-height.qml"));
    }

    function step(h, f) {
        if (!view)
            return false;
        if (f === 0) {
            h.walk(view, it => {
                if (it.cacheBuffer !== undefined && it.contentHeight !== undefined && it.contentHeight > it.height + 1 && it.orientation === ListView.Vertical)
                    lists.push(it);
            });
            h.note(`scrolling lists: ${lists.length}`);
        }
        lists.forEach((l, i) => {
            const max = l.contentHeight - l.height;
            l.contentY = Math.max(0, max * f / (frames - 1));
            lo[i] = Math.min(lo[i] ?? 1e9, l.contentHeight);
            hi[i] = Math.max(hi[i] ?? 0, l.contentHeight);
            if (f === frames - 1)
                h.note(`${hi[i] - lo[i] > 1 ? "FAIL" : "PASS"} list ${i}: ${l.count} rows, contentHeight ${lo[i].toFixed(0)}..${hi[i].toFixed(0)}`);
        });
    }

    function finish() {
        view?.destroy();
    }
}
