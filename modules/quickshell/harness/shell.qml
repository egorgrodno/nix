import QtQuick
import Quickshell

// The offscreen harness: a BosunConversation on injected entries, which each
// scenario in `scn-*.qml` steps through, timing every step with a synchronous
// grab of the scene. Started by `run`, which sets the environment:
// PANE (session or desk), SCENARIOS (comma list), N (entries), STEPS (frames
// of a scenario that sets none), SETTLE (ms from the injection to the first
// scenario) and SNAPS (where a scenario's PNGs go).
//
// A scenario is a QtObject with `frames`, `setup(h)`, `step(h, f)` and
// `finish(h)`, all optional; `h` is this window. `step` returns false to skip
// the scenario, as when it finds nothing to act on.
FloatingWindow {
    id: win

    readonly property string pane: Quickshell.env("PANE") || "session"
    readonly property int n: parseInt(Quickshell.env("N") ?? "") || 50
    readonly property int steps: parseInt(Quickshell.env("STEPS") ?? "") || 120
    readonly property var names: (Quickshell.env("SCENARIOS") ?? "").split(",").filter(s => s !== "")
    readonly property string snaps: Quickshell.env("SNAPS") ?? ""
    // Frames to run before the first one is timed.
    readonly property int warmup: 3

    readonly property alias conv: loader.item
    // The ListView, reached through its cacheBuffer.
    property var list: null

    property var scenarios: []
    property int index: -1
    property var scenario: null
    property string label
    property int frame: 0
    property var times: []
    property bool skipped: false

    implicitWidth: 560
    implicitHeight: 800
    color: Theme.backgroundRaised

    function walk(item, fn) {
        fn(item);
        for (const c of item.children ?? [])
            walk(c, fn);
        if (item.contentItem && item.contentItem !== item)
            walk(item.contentItem, fn);
    }

    // The deepest-first match of `pred` with the greatest `length`, or null.
    function find(pred) {
        let best = null;
        walk(conv, it => {
            if (pred(it) && (!best || it.length > best.length))
                best = it;
        });
        return best;
    }

    // Whether `item` lies in the conversation's view.
    function inView(item) {
        const y = item.mapToItem(null, 0, 0).y;
        return y > -50 && y < height - 100;
    }

    // Scrolls the row at `i` of the conversation's rows to the view's top.
    function show(i) {
        list.positionViewAtIndex(i, ListView.Beginning);
    }

    // The index of the first row `pred` accepts, from `from`.
    function rowIndex(pred, from) {
        const rows = conv.rows;
        for (let i = from ?? 0; i < rows.length; i++)
            if (pred(rows[i]))
                return i;
        return -1;
    }

    // A line of the scenario's own, printed after its summary.
    function note(text) {
        console.log(`HARNESS note ${label}: ${text}`);
    }

    // Saves the conversation as `snaps`/`name`.png, for comparing looks.
    function snap(name) {
        if (snaps === "")
            return;
        conv.grabToImage(r => r.saveToFile(`${snaps}/${pane}-${name}.png`));
    }

    function census() {
        let items = 0;
        let texts = 0;
        walk(conv, it => {
            items++;
            if (it.selectByMouse !== undefined)
                texts++;
        });
        return `items=${items} texts=${texts}`;
    }

    function summary(t) {
        const s = t.slice().sort((a, b) => a - b);
        const q = p => s[Math.min(s.length - 1, Math.floor(s.length * p))];
        const mean = t.reduce((a, b) => a + b, 0) / t.length;
        return `frames=${t.length} mean=${mean.toFixed(1)} med=${q(0.5).toFixed(1)} p95=${q(0.95).toFixed(1)} max=${s[s.length - 1].toFixed(1)} ms`;
    }

    function load() {
        for (const name of names) {
            const component = Qt.createComponent(Qt.resolvedUrl(`scn-${name}.qml`));
            if (component.status !== Component.Ready) {
                console.log(`HARNESS ${pane} ${name} cannot load: ${component.errorString().split("\n")[0]}`);
                continue;
            }
            scenarios.push({
                name,
                object: component.createObject(win)
            });
        }
    }

    function start() {
        walk(conv, it => {
            if (it.cacheBuffer !== undefined)
                list = it;
        });
        load();
        advance();
    }

    // Moves to the next scenario, or ends the run.
    function advance() {
        index++;
        if (index >= scenarios.length) {
            Qt.quit();
            return;
        }
        label = scenarios[index].name;
        scenario = scenarios[index].object;
        times = [];
        skipped = false;
        frame = -warmup;
        scenario.setup?.(win);
        tick();
    }

    function finish() {
        const head = `${pane} ${label}`.padEnd(24);
        if (skipped)
            console.log(`HARNESS ${head} skipped: nothing to act on`);
        else
            console.log(`HARNESS ${head} ${summary(times)} ${census()}`);
        scenario.finish?.(win);
        advance();
    }

    // One step, then a synchronous grab of the scene: polish, sync and render
    // all land before the callback, whatever the platform's frame pacing,
    // which offscreen caps at 60 Hz.
    function tick() {
        const total = scenario.frames > 0 ? scenario.frames : steps;
        const t0 = Date.now();
        if (frame >= 0 && scenario.step?.(win, frame) === false) {
            skipped = true;
            finish();
            return;
        }
        conv.grabToImage(() => {
            if (frame >= 0)
                times.push(Date.now() - t0);
            frame++;
            if (frame >= total)
                finish();
            else
                tick();
        }, Qt.size(280, 400));
    }

    // The panel as the session pane or the desk pane builds it, on no node
    // and following nothing, its entries fed through the feed's own
    // `receive`.
    Loader {
        id: loader

        anchors.fill: parent
        sourceComponent: win.pane === "desk" ? deskView : sessionView
    }

    Component {
        id: sessionView

        BosunConversation {
            node: "select-lag"
            parentNode: "master"
            live: false
        }
    }

    Component {
        id: deskView

        BosunConversation {
            node: "desk"
            live: false
            shape: entries => BosunDesk.shape(entries)
        }
    }

    HarnessData {
        id: data
    }

    // Keeps frames coming, so each tick is a frame's worth of work.
    Rectangle {
        width: 4
        height: 4
        color: "red"
        RotationAnimation on rotation {
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
        }
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: {
            Bosun.receive(JSON.stringify({
                type: "snapshot",
                sessions: data.sessions,
                decisions: data.decisions,
                answered: data.answered,
                log: data.log(win.n)
            }));
            const feed = win.conv.feed;
            const entries = win.pane === "desk" ? data.desk(win.n) : data.session(win.n);
            feed.receive(JSON.stringify({
                type: "reset",
                session: "harness"
            }));
            feed.receive(JSON.stringify({
                type: "entries",
                entries,
                more: false
            }));
            feed.receive(JSON.stringify({
                type: "progress",
                tempo: "idle"
            }));
            console.log(`HARNESS injected ${entries.length} ${win.pane} entries`);
            settle.start();
        }
    }

    Timer {
        id: settle

        interval: parseInt(Quickshell.env("SETTLE") ?? "") || 2500
        onTriggered: win.start()
    }
}
