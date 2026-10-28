import QtQuick

// A mouse drag that grows a selection down an edit's diff.
QtObject {
    property var target: null

    function setup(h) {
        target = null;
        h.show(Math.max(0, h.rowIndex(e => e.kind === "tool" && (e.result?.diff ?? []).length > 0)));
    }

    function step(h, f) {
        if (f === 0) {
            target = h.find(it => it.press !== undefined && it.laidOut !== undefined && h.inView(it));
            if (!target)
                return false;
            target.press(5, 5);
        }
        target.drag(target.width * 0.9, target.height * (f + 1) / h.steps);
    }

    function finish(h) {
        target?.clearSelection();
    }
}
