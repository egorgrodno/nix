import QtQuick

// Waiting on you as decisions arrive and leave: the sidebar's rows and the
// overview's cards open and close over a few frames, an answered decision the
// sidebar holds stays whole until the selection moves off it, and the count's
// badge shrinks away at 0. Builds both over the stage, feeds the daemon's
// events, and a PASS or FAIL note says what each frame found. Runs on the
// session pane only.
QtObject {
    property int frames: 44
    property var sidebar: null
    property var overview: null
    property var backdrop: null

    // The row or card shown for `key`, as its BosunReveal: its `shown` runs
    // from 0 to 1.
    function slot(h, root, key) {
        let found = null;
        h.walk(root, it => {
            if (it.shown !== undefined && it.full !== undefined && (it.modelData?.key ?? `decision:${it.modelData?.id}`) === key)
                found = it;
        });
        return found;
    }

    function badge(h) {
        let found = null;
        h.walk(sidebar, it => {
            if (it.swell !== undefined && it.visible)
                found = it;
        });
        return found;
    }

    function event(e) {
        Bosun.receive(JSON.stringify({
            event: e
        }));
    }

    function decide(id, node) {
        event({
            kind: "decision",
            decision: {
                id: `${id}`,
                holder: "user",
                node,
                kind: "permission",
                tool: "Bash",
                input: {
                    command: `make check ${id}`
                }
            }
        });
    }

    function settle(id) {
        event({
            kind: "settled",
            id: `${id}`
        });
    }

    // Partway is a row still there, short of whole: a frame here can outlast
    // the animation, which leaves a row at 0 until the list lets it go.
    function check(h, what, root, key, wanted) {
        const s = slot(h, root, key);
        const shown = s ? s.shown : -1;
        const ok = wanted === "gone" ? s === null : wanted === "partway" ? s !== null && shown < 1 : s !== null && shown === 1 && Math.abs(s.height - s.full) < 0.5;
        h.note(`${ok ? "PASS" : "FAIL"} ${what}: ${s ? `shown ${shown.toFixed(2)}, height ${s.height.toFixed(1)} of ${s.full}` : "no row"}`);
    }

    function setup(h) {
        if (h.pane !== "session")
            return;
        backdrop = Qt.createQmlObject("import QtQuick\nRectangle { z: 9; anchors.fill: parent; color: Theme.backgroundRaised }", h.conv.parent, Qt.resolvedUrl("scn-waiting.qml"));
        sidebar = Qt.createQmlObject("import QtQuick\nBosunSidebar { z: 10; width: 380; height: 780; selected: \"desk\" }", h.conv.parent, Qt.resolvedUrl("scn-waiting.qml"));
        overview = Qt.createQmlObject("import QtQuick\nBosunOverview { z: 11; x: 390; width: 440 }", h.conv.parent, Qt.resolvedUrl("scn-waiting.qml"));
    }

    function step(h, f) {
        if (!sidebar)
            return false;
        switch (f) {
        case 0:
            decide(12, "panel-ipc");
            break;
        case 1:
            check(h, "a sidebar row arrives partway", sidebar, "decision:12", "partway");
            check(h, "an overview card arrives partway", overview, "decision:12", "partway");
            h.snap("waiting-arriving");
            break;
        case 6:
            check(h, "the sidebar row has arrived", sidebar, "decision:12", "whole");
            check(h, "the overview card has arrived", overview, "decision:12", "whole");
            h.snap("waiting-arrived");
            settle(12);
            break;
        case 7:
            check(h, "a settled row leaves partway", sidebar, "decision:12", "partway");
            check(h, "a settled card leaves partway", overview, "decision:12", "partway");
            break;
        case 12:
            check(h, "the settled row has left", sidebar, "decision:12", "gone");
            check(h, "the settled card has left", overview, "decision:12", "gone");
            decide(14, "panel-ipc");
            break;
        case 18:
            // Selected, as the view holds it.
            sidebar.selected = "decision:14";
            sidebar.held = Bosun.mine.find(d => d.id === "14");
            settle(14);
            break;
        case 19:
        case 24:
            check(h, "an answered row holds while selected", sidebar, "decision:14", "whole");
            if (f === 24) {
                h.snap("waiting-held");
                sidebar.selected = "desk";
                sidebar.held = null;
            }
            break;
        case 25:
            check(h, "the held row leaves partway once the selection moves", sidebar, "decision:14", "partway");
            h.snap("waiting-leaving");
            break;
        case 30:
            check(h, "the held row has left", sidebar, "decision:14", "gone");
            settle(7);
            break;
        case 31:
            {
                const b = badge(h);
                const ok = b !== null && b.appear > 0 && b.appear < 1 && b.shownCount === 1;
                h.note(`${ok ? "PASS" : "FAIL"} the badge shrinks away at 0 with its last number: ${b ? `appear ${b.appear.toFixed(2)}, shows ${b.shownCount}` : "none"}`);
                check(h, "the line in place of rows arrives partway", sidebar, "nothing", "partway");
                break;
            }
        case 37:
            h.note(`${badge(h) === null ? "PASS" : "FAIL"} the badge is gone at 0`);
            check(h, "the line in place of rows has arrived", sidebar, "nothing", "whole");
            check(h, "the line in place of cards has arrived", overview, "decision:nothing", "whole");
            h.snap("waiting-none");
            decide(7, "select-lag");
            break;
        case 43:
            check(h, "decision 7 is back", sidebar, "decision:7", "whole");
            check(h, "the line in place of rows has left", sidebar, "nothing", "gone");
            check(h, "card 7 is back", overview, "decision:7", "whole");
            check(h, "the line in place of cards has left", overview, "decision:nothing", "gone");
            break;
        }
    }

    function finish() {
        overview?.destroy();
        sidebar?.destroy();
        backdrop?.destroy();
    }
}
