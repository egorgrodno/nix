import QtQuick

// The desk and session panes' composers draw grey text only for a suggestion:
// an empty one with nothing to suggest shows none, and one with a suggestion
// shows it. Builds the real pane over the stage, since the harness shows only
// its conversation, and prints a PASS or FAIL note per case.
QtObject {
    property var pane: null
    property var composer: null

    // The grey texts the composer draws over its empty field.
    function grey(h) {
        const found = [];
        const seen = new Set();
        h.walk(composer, it => {
            if (it.parent?.selectByMouse !== undefined && it.visible && it.text && !seen.has(it)) {
                seen.add(it);
                found.push(it.text);
            }
        });
        return found;
    }

    function setup(h) {
        const type = h.pane === "desk" ? "BosunDeskPane" : "BosunSessionPane";
        const component = Qt.createQmlObject(`import QtQuick\nComponent { ${type} { z: 10; width: 560; height: 400 } }`, h.conv.parent, Qt.resolvedUrl("scn-composer-suggestion.qml"));
        pane = component.createObject(h.conv.parent, h.pane === "desk" ? {} : {
            session: Bosun.sessions.find(s => s.node === "select-lag")
        });
        composer = null;
        h.walk(pane, it => {
            if (it.suggesting !== undefined)
                composer = it;
        });
        if (!composer)
            return;
        composer.text = "";
        composer.suggestion = "";
    }

    function step(h, f) {
        if (!composer)
            return false;
        if (f === 0) {
            const g = grey(h);
            h.note(`${composer.visible && g.length === 0 ? "PASS" : "FAIL"} empty, no suggestion: composer visible=${composer.visible}, grey text [${g}]`);
            h.snap("composer-empty");
            composer.suggestion = "Yes, go ahead";
        }
        if (f === 2) {
            const g = grey(h);
            h.note(`${g.length === 1 && g[0] === "Yes, go ahead" ? "PASS" : "FAIL"} empty, suggestion: composer visible=${composer.visible}, grey text [${g}]`);
            h.snap(Qt.resolvedUrl("scn-composer-suggestion.qml"));
        }
    }

    function finish() {
        pane?.destroy();
    }
}
