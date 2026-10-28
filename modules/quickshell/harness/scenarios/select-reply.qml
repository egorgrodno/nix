import QtQuick

// A mouse drag that grows a selection down the longest reply in view.
QtObject {
    property var target: null

    function setup(h) {
        target = null;
        h.show(Math.max(0, h.rowIndex(e => e.kind === "text" || e.kind === "desk-text")));
    }

    function step(h, f) {
        if (f === 0) {
            target = h.find(it => it.press !== undefined && it.laidOut === undefined && it.textFormat === TextEdit.RichText && h.inView(it));
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
