pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// The bosun panel's content: the titlebar, a banner while the fleet is
// paused, then the sidebar, and beside it the selected row whole, or the New
// worker form. Expanded to the work area, the sidebar shrinks to a rail of its
// sections, which can show the sidebar beside it again. There the Log becomes
// a table with the selected entry whole beside it, and any other pane keeps to
// a column narrow enough to read. Keys act only while no text field has
// focus, which starts in the sidebar. Approving, denying and pausing take a
// second press of the same key within three seconds: the first arms and
// lights the button, and any other key or a move disarms it.
Item {
    id: view

    // Where Panel.qml sends the keyboard from a field a press lands outside:
    // the list beside the pane.
    readonly property Item keyboardHome: logShown ? logTable : sidebar.visible ? sidebar : rail

    // The selected row's key, as BosunSidebar names them, or "spawn" while the
    // New worker form is open.
    property string selected: ""
    // What the form returns to.
    property string beforeSpawn: ""
    // The selected decision, kept once it no longer waits on the user.
    property var held: null
    // The key a first press armed: "a", "d" or "p".
    property string armed: ""
    // The worker a first click on Kill armed.
    property string killing: ""
    // The Log entry selected, kept once it scrolls out of the sidebar.
    property var logEntry: null
    // While the panel fills the work area.
    property bool expanded: false
    // While the expanded panel shows the whole sidebar beside the rail.
    property bool sidebarShown: false

    readonly property string paneKind: {
        if (selected === "spawn")
            return "spawn";
        if (selected === "desk")
            return Bosun.desk ? "desk" : "session";
        return selected.split(":")[0];
    }
    // The rail's section the selection is in.
    readonly property string section: {
        if (selected === "desk")
            return "desk";
        return ({
                decision: "waiting",
                session: "fleet",
                log: "log"
            })[paneKind] ?? "";
    }
    readonly property bool logShown: expanded && paneKind === "log"
    readonly property var decision: {
        if (paneKind !== "decision")
            return null;
        const id = selected.slice("decision:".length);
        return Bosun.decisions.find(d => d.id === id) ?? (held?.id === id ? held : null);
    }
    readonly property bool decisionLive: decision !== null && Bosun.mine.some(d => d.id === decision.id)
    readonly property var session: {
        if (selected === "desk")
            return Bosun.master;
        const node = selected.slice("session:".length);
        return Bosun.sessions.find(s => s.node === node) ?? null;
    }

    function defaultKey() {
        if (!Bosun.connected)
            return "";
        return Bosun.mine.length > 0 ? `decision:${Bosun.mine[0].id}` : "desk";
    }

    // `item` is what to show for the key once its row is gone: a settled
    // decision or a Log entry, as the Log holds them.
    function select(key, item) {
        if (key === selected)
            return;
        armed = "";
        killing = "";
        const live = Bosun.mine.find(d => `decision:${d.id}` === key);
        held = live ?? (key.startsWith("decision:") ? item ?? null : null);
        if (key.startsWith("log:"))
            logEntry = item ?? Bosun.log.find(e => `log:${e.seq}` === key) ?? logEntry;
        selected = key;
    }

    // Through the Log's table while it shows and the sidebar does not have the
    // keyboard, else through the sidebar's rows, shown or not.
    function move(step) {
        if (logShown && !sidebar.activeFocus) {
            logTable.move(step);
            return;
        }
        const keys = sidebar.keys;
        const from = keys.indexOf(selected === "spawn" ? beforeSpawn : selected);
        if (keys.length === 0)
            return;
        select(keys[from < 0 ? 0 : Math.max(0, Math.min(keys.length - 1, from + step))]);
    }

    // A rail glyph: its section's first row, unless the selection is in it.
    function openSection(name) {
        if (name === section)
            return;
        switch (name) {
        case "waiting":
            if (sidebar.waiting.length > 0)
                select(`decision:${sidebar.waiting[0].id}`);
            break;
        case "desk":
            select("desk");
            break;
        case "fleet":
            if (sidebar.tree.length > 0)
                select(`session:${sidebar.tree[0].node}`);
            break;
        case "log":
            openLog();
            break;
        }
    }

    // The entry last selected, else the latest.
    function openLog() {
        if (paneKind === "log")
            return;
        const entry = logEntry ?? Bosun.log[Bosun.log.length - 1];
        if (entry)
            select(`log:${entry.seq}`, entry);
    }

    function setExpanded(on) {
        expanded = on;
        Qt.callLater(keepKeyboard);
    }

    // An item that hides keeps the keyboard, so it follows the list as the
    // list changes.
    function keepKeyboard() {
        const focused = view.Window.activeFocusItem;
        for (let item = focused; focused?.visible && item; item = item.parent)
            if (item === view)
                return;
        keyboardHome.forceActiveFocus();
    }

    function currentPane() {
        switch (paneKind) {
        case "decision":
            return decisionPane;
        case "desk":
            return deskPane;
        case "session":
            return sessionPane;
        case "log":
            return logPane;
        case "spawn":
            return spawnPane;
        }
        return null;
    }

    // To the field the pane takes, else to the pane, where keys still act.
    function focusPane() {
        const pane = currentPane();
        if (!(pane?.focusIn?.() ?? false))
            paneKeys.forceActiveFocus();
    }

    function openSpawn() {
        if (!Bosun.connected)
            return;
        if (selected !== "spawn") {
            beforeSpawn = selected;
            select("spawn");
            spawnPane.findRepos();
        }
        Qt.callLater(focusPane);
    }

    function closeSpawn() {
        select(beforeSpawn !== "" ? beforeSpawn : defaultKey());
        keyboardHome.forceActiveFocus();
    }

    function arm(key) {
        armed = key;
        disarm.restart();
    }

    // Acts on the second of two presses of `key`, `was` holding what the
    // first armed.
    function twice(key, was, act) {
        if (was === key)
            act();
        else
            arm(key);
        return true;
    }

    function pause() {
        if (armed !== "p") {
            arm("p");
            return;
        }
        armed = "";
        Bosun.pause();
    }

    function kill(node) {
        if (killing !== node) {
            killing = node;
            disarm.restart();
            return;
        }
        killing = "";
        Bosun.kill(node);
    }

    // Once the user's answer settles the selected decision, to the next one
    // waiting. The daemon logs the answer just after it settles the decision.
    function advance() {
        if (!held || selected !== `decision:${held.id}` || Bosun.mine.some(d => d.id === held.id) || Bosun.mine.length === 0)
            return;
        if (Bosun.settledEntry(held.id)?.by !== "user")
            return;
        const next = Bosun.mine.find(d => Number(d.id) > Number(held.id)) ?? Bosun.mine[Bosun.mine.length - 1];
        select(`decision:${next.id}`);
    }

    function press(event) {
        if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R].includes(event.key))
            return false;
        const was = armed;
        armed = "";
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return false;
        const onLog = logShown && (logTable.activeFocus || rail.activeFocus);
        switch (event.key) {
        case Qt.Key_Down:
            move(1);
            return true;
        case Qt.Key_Up:
            move(-1);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (onLog)
                logTable.openNamed();
            else
                focusPane();
            return true;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            if (sidebar.activeFocus || rail.activeFocus || logTable.activeFocus)
                focusPane();
            else
                keyboardHome.forceActiveFocus();
            return true;
        // Out of the expanded size, else on to Panel.qml, which closes.
        case Qt.Key_Escape:
            if (!expanded)
                return false;
            setExpanded(false);
            return true;
        }
        const live = decisionLive ? decision.kind : "";
        switch (event.text) {
        case "j":
            move(1);
            return true;
        case "k":
            move(-1);
            return true;
        case "a":
            return live === "permission" && twice("a", was, () => decisionPane.approve());
        case "d":
            return live === "permission" && twice("d", was, () => decisionPane.deny());
        case "D":
            decisionPane.focusNote();
            return live === "permission";
        case "r":
            decisionPane.focusReply();
            return live === "question";
        case "t":
            if (!Bosun.connected)
                return false;
            select("desk");
            Qt.callLater(focusPane);
            return true;
        case "n":
            openSpawn();
            return true;
        case "p":
            if (!Bosun.connected || Bosun.fleetOp !== "")
                return false;
            return twice("p", was, () => Bosun.paused ? Bosun.unpause() : Bosun.pause());
        case "f":
            setExpanded(!expanded);
            return true;
        }
        return false;
    }

    onKeyboardHomeChanged: Qt.callLater(keepKeyboard)
    Component.onCompleted: {
        select(defaultKey());
        keyboardHome.forceActiveFocus();
    }

    Connections {
        target: Bosun

        function onMineChanged() {
            const live = Bosun.mine.find(d => `decision:${d.id}` === view.selected);
            if (live)
                view.held = live;
            else if (view.held && view.selected === `decision:${view.held.id}`)
                Qt.callLater(view.advance);
        }

        function onLogChanged() {
            view.advance();
        }

        function onConnectedChanged() {
            view.select(view.defaultKey());
        }

        // A session gone takes its row with it.
        function onSessionsChanged() {
            if (view.selected.startsWith("session:") && view.session === null)
                view.select(view.defaultKey());
        }
    }

    Timer {
        id: disarm

        interval: 3000
        onTriggered: {
            view.armed = "";
            view.killing = "";
        }
    }

    Item {
        anchors.fill: parent

        BosunTitlebar {
            id: titlebar

            width: parent.width
            pauseArmed: view.armed === "p"
            spawning: view.selected === "spawn"
            expanded: view.expanded
            onPauseClicked: view.pause()
            onResumeClicked: Bosun.unpause()
            onNewWorkerClicked: view.selected === "spawn" ? view.closeSpawn() : view.openSpawn()
            onExpandClicked: view.setExpanded(!view.expanded)
        }

        Rectangle {
            id: banner

            anchors.top: titlebar.bottom
            width: parent.width
            height: visible ? bannerText.implicitHeight + 20 : 0
            visible: Bosun.paused || Bosun.fleetOp === "pause"
            color: Theme.alpha(Theme.yellow, 0.12)

            BarText {
                id: bannerGlyph

                x: 20
                y: 10
                text: BosunLook.states.paused.glyph
                color: Theme.yellow
                font.pixelSize: 14
            }

            BarText {
                id: bannerText

                anchors.left: bannerGlyph.right
                anchors.leftMargin: 10
                y: 10
                width: parent.width - x - 20
                wrapMode: Text.Wrap
                color: Theme.yellow
                font.pixelSize: 14
                text: {
                    if (Bosun.fleetOp === "pause")
                        return "Pausing: stopping every session.";
                    const turns = Bosun.sessions.filter(s => s.paused).map(s => s.node);
                    const named = turns.length > 1 ? `${turns.slice(0, -1).join(", ")} and ${turns[turns.length - 1]}` : turns[0];
                    return turns.length > 0 ? `Paused. Nothing resumes on its own until you press Resume, which restarts the turns of ${named}.` : "Paused. Nothing resumes on its own until you press Resume. No session was in its turn.";
                }
            }
        }

        // Why the last command failed, until the next one.
        Rectangle {
            id: errorStrip

            anchors.top: banner.bottom
            width: parent.width
            height: visible ? errorText.implicitHeight + 20 : 0
            visible: Bosun.error !== ""
            color: Theme.alpha(Theme.red, 0.12)

            BarText {
                id: errorGlyph

                x: 20
                y: 10
                text: BosunLook.alert
                color: Theme.yellow
                font.pixelSize: 14
            }

            BarText {
                id: errorText

                anchors.left: errorGlyph.right
                anchors.leftMargin: 10
                y: 10
                width: parent.width - x - 20
                wrapMode: Text.Wrap
                color: Theme.yellow
                font.pixelSize: 14
                text: Bosun.error
            }
        }

        // The rail while expanded, the sidebar, the Log's table while it
        // shows, and the pane, each after a 1-pixel rule.
        Item {
            id: body

            // Where the panes start, past the rail and the sidebar.
            readonly property real paneLeft: (view.expanded ? rail.width + 1 : 0) + (sidebar.visible ? sidebar.width + 1 : 0)
            readonly property real rest: width - paneLeft

            anchors.top: errorStrip.bottom
            anchors.bottom: parent.bottom
            width: parent.width

            BosunRail {
                id: rail

                height: parent.height
                visible: view.expanded
                section: view.section
                sidebarShown: view.sidebarShown
                onPicked: name => view.openSection(name)
                onSidebarToggled: view.sidebarShown = !view.sidebarShown
                Keys.onPressed: event => event.accepted = view.press(event)
            }

            Rule {
                x: rail.width
                visible: rail.visible
            }

            BosunSidebar {
                id: sidebar

                x: view.expanded ? rail.width + 1 : 0
                height: parent.height
                width: 380
                visible: !view.expanded || view.sidebarShown
                expanded: view.expanded
                selected: view.selected
                held: view.held
                onChosen: key => {
                    view.select(key);
                    sidebar.forceActiveFocus();
                }
                onLogExpanded: {
                    view.setExpanded(true);
                    view.openLog();
                }
                Keys.onPressed: event => event.accepted = view.press(event)
            }

            Rule {
                x: sidebar.x + sidebar.width
                visible: sidebar.visible
            }

            BosunLogTable {
                id: logTable

                x: body.paneLeft
                width: body.rest - detail.column - 1
                height: parent.height
                visible: view.logShown
                selectedSeq: view.selected.startsWith("log:") ? Number(view.selected.slice("log:".length)) : -1
                onChosen: entry => view.select(`log:${entry.seq}`, entry)
                onOpened: (key, item) => view.select(key, item)
                Keys.onPressed: event => event.accepted = view.press(event)
            }

            Rule {
                x: logTable.x + logTable.width
                visible: logTable.visible
            }

            // The selected row whole: beside the Log's table at 860 pixels,
            // else in what the panel leaves, at most 1200 wide.
            Item {
                id: detail

                readonly property real column: view.logShown ? 860 : view.expanded ? Math.min(body.rest, 1200) : body.rest

                x: view.logShown ? body.width - column : body.paneLeft + (body.rest - column) / 2
                width: column
                height: parent.height

                // The pane's own keyboard, where the keys act as in the sidebar.
                Item {
                    id: paneKeys

                    Keys.onPressed: event => event.accepted = view.press(event)
                }

                Caption {
                    anchors.centerIn: parent
                    visible: !Bosun.connected
                    text: "bosun watch reconnects once the daemon runs"
                }

                BosunDecisionPane {
                    id: decisionPane

                    anchors.fill: parent
                    visible: view.paneKind === "decision" && view.decision !== null
                    decision: view.decision
                    live: view.decisionLive
                    armed: view.armed
                    onLeave: view.keyboardHome.forceActiveFocus()
                }

                BosunDeskPane {
                    id: deskPane

                    anchors.fill: parent
                    visible: view.paneKind === "desk"
                    onLeave: view.keyboardHome.forceActiveFocus()
                }

                BosunSessionPane {
                    id: sessionPane

                    anchors.fill: parent
                    visible: view.paneKind === "session" && view.session !== null
                    session: view.session
                    killArmed: view.killing !== "" && view.killing === (view.session?.node ?? "")
                    onKillClicked: view.kill(view.session.node)
                    onLeave: view.keyboardHome.forceActiveFocus()
                }

                BosunLogPane {
                    id: logPane

                    anchors.fill: parent
                    visible: view.paneKind === "log" && view.logEntry !== null
                    entry: view.logEntry
                    onOpened: (key, item) => view.select(key, item)
                }

                BosunSpawnPane {
                    id: spawnPane

                    anchors.fill: parent
                    visible: view.paneKind === "spawn" && Bosun.connected
                    onCancelled: view.closeSpawn()
                    onStarted: view.closeSpawn()
                }
            }
        }
    }

    // The line between two of the body's columns.
    component Rule: Rectangle {
        width: 1
        height: parent?.height ?? 0
        color: Theme.tint(0.08)
    }
}
