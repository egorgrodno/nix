pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// The full bosun panel: the titlebar, a banner while the fleet is paused,
// then the sidebar, or the rail it collapses to, and beside it the selected
// row whole in a column narrow enough to read, or the New worker form. The Log
// is a table with the selected entry whole beside it. Keys act only while no
// text field has focus, which starts in the sidebar, and Ctrl+C copies the
// text the mouse selected, which never takes it. Approving, denying, pausing
// and clearing a conversation by key take a second press of the same key
// within three seconds, and so do Pause, Kill and Clear by click: the first
// arms and lights the button, and any other key or a move disarms it. Approve
// and Deny act on a single click.
Item {
    id: view

    // Where Panel.qml sends the keyboard from a field a press lands outside:
    // the list beside the pane.
    readonly property Item keyboardHome: logShown ? logTable : sidebarOpen ? sidebar : rail

    // BosunKept holds what the panel shows, so it opens where it closed.
    readonly property string selected: BosunKept.selected
    readonly property var held: BosunKept.held
    readonly property bool sidebarOpen: BosunKept.sidebarOpen
    // The key a first press armed: "y", "d", "p" or "C".
    property string armed: ""
    // How it was armed: "key" or "click".
    property string armedBy: "key"
    // The worker a first click on Kill armed.
    property string killing: ""
    // The decision the user's last answer from the panel settled.
    property string answered: ""

    readonly property string paneKind: {
        if (selected === "spawn")
            return "spawn";
        if (selected === "desk")
            return Bosun.desk ? "desk" : "session";
        return selected.split(":")[0];
    }
    readonly property bool logShown: paneKind === "log"
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
        if (paneKind !== "session")
            return null;
        const node = selected.slice("session:".length);
        return Bosun.sessions.find(s => s.node === node) ?? (held?.node === node && held?.kind === undefined ? held : null);
    }
    // BosunKept sets `held` just before `selected`, so each match checks it
    // belongs to the key.
    readonly property var logEntry: paneKind === "log" && `log:${held?.seq}` === selected ? held : null

    function defaultKey() {
        if (!Bosun.connected)
            return "";
        return Bosun.mine.length > 0 ? `decision:${Bosun.mine[0].id}` : "desk";
    }

    function select(key, item) {
        BosunKept.select(key, item);
    }

    // Through the Log's table while it shows and the sidebar does not have the
    // keyboard, else through the sidebar's rows, shown or not.
    function move(step) {
        if (logShown && !sidebar.activeFocus) {
            logTable.move(step);
            return;
        }
        const keys = sidebar.keys;
        const from = keys.indexOf(selected === "spawn" ? BosunKept.beforeSpawn : selected);
        if (keys.length === 0)
            return;
        select(keys[from < 0 ? 0 : Math.max(0, Math.min(keys.length - 1, from + step))]);
    }

    // A rail tile: Waiting on you opens the first decision, unless one is
    // selected, and the Log the entry last selected.
    function pickTile(key) {
        if (key === "waiting") {
            if (paneKind !== "decision" && sidebar.waiting.length > 0)
                select(`decision:${sidebar.waiting[0].id}`);
        } else if (key === "log")
            openLog();
        else
            select(key);
        rail.forceActiveFocus();
    }

    // The entry last selected, else the latest.
    function openLog() {
        if (paneKind === "log")
            return;
        const entry = BosunKept.logEntry ?? Bosun.log[Bosun.log.length - 1];
        if (entry)
            select(`log:${entry.seq}`, entry);
    }

    // What a Log entry names, which Enter opens as the log pane's hints say.
    function openNamed(entry) {
        const link = BosunLook.logLink(entry);
        if (link)
            select(link.key, link.item);
    }

    function toggleSidebar() {
        BosunKept.sidebarOpen = !BosunKept.sidebarOpen;
    }

    // "open", "closed" or "toggle", for a script.
    function setSidebar(how) {
        if (how === "toggle")
            toggleSidebar();
        else if (["open", "closed"].includes(how))
            BosunKept.sidebarOpen = how === "open";
        else
            return `no sidebar ${how}`;
        return "";
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
            BosunKept.beforeSpawn = selected;
            select("spawn");
            spawnPane.findRepos();
        }
        Qt.callLater(focusPane);
    }

    // Back to the row New worker came from, or, once that row is gone, such
    // as a decision settled meanwhile, to the first waiting or the desk.
    function closeSpawn() {
        const before = BosunKept.beforeSpawn;
        const there = before === "desk" || sidebar.keys.includes(before) || BosunKept.liveItem(before) !== null;
        select(there ? before : defaultKey());
        keyboardHome.forceActiveFocus();
    }

    function arm(key, by) {
        armed = key;
        armedBy = by;
        disarm.restart();
    }

    // Acts on the second of two presses of `key`, `was` holding what the
    // first armed.
    function twice(key, was, act) {
        if (was === key)
            act();
        else
            arm(key, "key");
        return true;
    }

    // The two-press actions by name, other than Kill, which keeps `killing`.
    readonly property var armKeys: ({
            approve: "y",
            deny: "d",
            pause: "p",
            clear: "C"
        })

    // Whether the key's two-press action is on offer, as the key and a click
    // both need.
    function armable(key) {
        switch (key) {
        case "y":
        case "d":
            return decisionLive && Bosun.kindOf(decision) === "permission";
        case "p":
            return Bosun.connected && Bosun.fleetOp === "";
        case "C":
            return clearable;
        }
        return false;
    }

    function pause() {
        if (armed !== "p") {
            arm("p", "click");
            return;
        }
        armed = "";
        Bosun.pause();
    }

    // The session whose context the pane beside shows Compact and Clear for:
    // the desk, or the master where there is no desk.
    readonly property string contextNode: {
        if (paneKind === "desk")
            return "desk";
        return paneKind === "session" && session?.node === "master" ? "master" : "";
    }
    readonly property bool clearable: Bosun.connected && Bosun.contextOp === "" && contextNode !== "" &&!(contextNode === "master" && Bosun.hasWorkers)

    function compact() {
        Bosun.compact(contextNode);
    }

    function clearNow() {
        armed = "";
        Bosun.clear(contextNode);
    }

    // A click arms Clear, and a second one clears.
    function clear() {
        if (!clearable)
            return;
        if (armed !== "C")
            arm("C", "click");
        else
            clearNow();
    }

    function armKill(node) {
        killing = node;
        disarm.restart();
    }

    function kill(node) {
        if (killing !== node) {
            armKill(node);
            return;
        }
        killing = "";
        Bosun.kill(node);
    }

    // What Bosun's IpcHandler asks of the panel for a script. It moves the
    // selection, the size and the keyboard and arms a two-press action, and
    // reaches no function that sends, interrupts, answers, kills or pauses.
    // Each returns "" when done, else why it did nothing.

    // The sidebar row `key`, or "log" for the Log, as a click on it chooses.
    function selectRow(key) {
        if (key === "log") {
            if (Bosun.log.length === 0)
                return "the Log is empty";
            openLog();
            return "";
        }
        if (!sidebar.keys.includes(key) && !(key.startsWith("log:") && BosunKept.liveItem(key)))
            return `no row ${key}`;
        select(key);
        return "";
    }

    // The first press of `action`, which only arms it: the second stays the
    // user's, within three seconds.
    function armAction(action) {
        if (action === "kill") {
            if (!sessionPane.visible || !sessionPane.killable)
                return "no worker is selected to kill";
            armed = "";
            armKill(session.node);
            return "";
        }
        const key = armKeys[action];
        if (key === undefined)
            return `no action ${action}`;
        if (!armable(key))
            return `${action} is not on offer here`;
        killing = "";
        arm(key, "key");
        return "";
    }

    function focusAt(where) {
        switch (where) {
        case "pane":
            focusPane();
            return "";
        case "list":
            keyboardHome.forceActiveFocus();
            return "";
        }
        return `no place ${where}`;
    }

    // Where the keyboard is: "sidebar", "rail", "table", "pane", a "field" of
    // the pane's, or "".
    function focusName() {
        const places = {
            sidebar: sidebar,
            rail: rail,
            table: logTable,
            pane: paneKeys
        };
        for (const name of Object.keys(places))
            if (places[name].activeFocus)
                return name;
        return view.Window.activeFocusItem ? "field" : "";
    }

    function panelState() {
        return {
            kind: paneKind,
            focus: focusName(),
            armed: killing !== "" ? "kill" : armed
        };
    }

    // Once the user's answer from the panel settles the selected decision, to
    // the next one waiting. The decision may go before the answer's command
    // exits, or after.
    function advance() {
        if (!held || selected !== `decision:${held.id}` || answered !== held.id || Bosun.mine.some(d => d.id === held.id) || Bosun.mine.length === 0)
            return;
        const next = Bosun.mine.find(d => Number(d.id) > Number(held.id)) ?? Bosun.mine[Bosun.mine.length - 1];
        select(`decision:${next.id}`);
    }

    function press(event) {
        if ([Qt.Key_Shift, Qt.Key_Control, Qt.Key_Alt, Qt.Key_Meta, Qt.Key_Super_L, Qt.Key_Super_R].includes(event.key))
            return false;
        const was = armed;
        armed = "";
        killing = "";
        if (event.matches(StandardKey.Copy))
            return MouseSelection.copy();
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
            else if (logEntry)
                openNamed(logEntry);
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
        // From the pane back to the list, else on to Panel.qml, which closes.
        case Qt.Key_Escape:
            if (!paneKeys.activeFocus)
                return false;
            keyboardHome.forceActiveFocus();
            return true;
        }
        switch (event.text) {
        case Host.directions.down:
            move(1);
            return true;
        case Host.directions.up:
            move(-1);
            return true;
        }
        const live = decisionLive ? Bosun.kindOf(decision) : "";
        // Each layout's direction keys move, so an action here takes none of
        // h j k l g a e o, in either case.
        switch (event.text) {
        case "y":
            return armable("y") && twice("y", was, () => decisionPane.approve());
        case "d":
            return armable("d") && twice("d", was, () => decisionPane.deny());
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
            return true;
        case "n":
            openSpawn();
            return true;
        case "p":
            return armable("p") && twice("p", was, () => Bosun.paused ? Bosun.unpause() : Bosun.pause());
        case "m":
            return currentPane()?.openModel?.() ?? false;
        case "c":
            if (!Bosun.connected || contextNode === "")
                return false;
            compact();
            return true;
        case "C":
            return armable("C") && twice("C", was, clearNow);
        case "f":
            BosunKept.full = false;
            return true;
        case "[":
            toggleSidebar();
            return true;
        case "/":
            if (!logShown)
                return false;
            logTable.focusFilter();
            return true;
        }
        return false;
    }

    onKeyboardHomeChanged: following.restart()
    // A notification's click moves the selection too.
    onSelectedChanged: {
        armed = "";
        killing = "";
    }
    Component.onCompleted: {
        if (selected === "")
            select(defaultKey());
        keyboardHome.forceActiveFocus();
    }

    // The selection stays where it is as rows come and go: only the user's
    // own answer from the panel moves it on.
    Connections {
        target: Bosun

        function onMineChanged() {
            if (view.paneKind === "decision" && !view.decisionLive)
                Qt.callLater(view.advance);
        }

        function onLogChanged() {
            view.advance();
        }

        function onFinished(args, ok) {
            if (ok && ["approve", "deny", "reply", "dismiss"].includes(args[0])) {
                view.answered = args[1];
                view.advance();
            }
        }

        function onConnectedChanged() {
            if (view.selected === "")
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

    // Once the list has changed. A timer rather than Qt.callLater, which
    // outlives the panel as it closes.
    Timer {
        id: following

        interval: 0
        onTriggered: view.keepKeyboard()
    }

    Item {
        anchors.fill: parent

        BosunTitlebar {
            id: titlebar

            width: parent.width
            pauseArmed: view.armed === "p"
            pauseByKey: view.armedBy === "key"
            spawning: view.selected === "spawn"
            sidebarOpen: view.sidebarOpen
            onPauseClicked: view.pause()
            onResumeClicked: Bosun.unpause()
            onNewWorkerClicked: view.selected === "spawn" ? view.closeSpawn() : view.openSpawn()
            onSidebarToggled: view.toggleSidebar()
            onOverviewClicked: BosunKept.full = false
        }

        // Whatever bands the panel shows under the title bar; a hidden one
        // takes no height.
        Column {
            id: strips

            anchors.top: titlebar.bottom
            width: parent.width

            BosunBanner {
                strip: true
                visible: Bosun.paused || Bosun.fleetOp === "pause"
                glyph: BosunLook.states.paused.glyph
                tint: Theme.yellow
                text: {
                    if (Bosun.fleetOp === "pause")
                        return "Pausing: stopping every session.";
                    const turns = Bosun.sessions.filter(s => s.paused).map(s => s.node);
                    const named = turns.length > 1 ? `${turns.slice(0, -1).join(", ")} and ${turns[turns.length - 1]}` : turns[0];
                    return turns.length > 0 ? `Paused. Nothing resumes on its own until you press Resume, which restarts the turns of ${named}.` : "Paused. Nothing resumes on its own until you press Resume. No session was in its turn.";
                }
            }

            // Why the last command failed, until the next one.
            BosunBanner {
                strip: true
                visible: Bosun.error !== ""
                glyph: BosunLook.alert
                tint: Theme.yellow
                fill: Theme.red
                text: Bosun.error
            }
        }

        // The sidebar or its rail, the Log's table while it shows, and the
        // pane, each after a 1-pixel rule. The sidebar collapsed still gives
        // the movement keys its rows.
        Item {
            id: body

            // Where the panes start, past the sidebar or the rail.
            readonly property real paneLeft: (view.sidebarOpen ? sidebar.width : rail.width) + 1
            readonly property real rest: width - paneLeft

            anchors.top: strips.bottom
            anchors.bottom: parent.bottom
            width: parent.width

            BosunRail {
                id: rail

                height: parent.height
                visible: !view.sidebarOpen
                selected: view.selected
                onPicked: key => view.pickTile(key)
                Keys.onPressed: event => event.accepted = view.press(event)
            }

            Rule {
                x: rail.width
                visible: rail.visible
            }

            BosunSidebar {
                id: sidebar

                height: parent.height
                width: 380
                visible: view.sidebarOpen
                selected: view.selected
                held: view.paneKind === "decision" ? view.decision : null
                onChosen: key => {
                    view.select(key);
                    sidebar.forceActiveFocus();
                }
                onLogOpened: {
                    view.openLog();
                    sidebar.forceActiveFocus();
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

            // The selected row whole: beside the Log's table at about a third
            // of what the panel leaves, as the mockup has it, else centred in
            // that, at most 1200 wide.
            Item {
                id: detail

                readonly property real column: view.logShown ? Math.round(body.rest * 0.35) : Math.min(body.rest, 1200)

                x: view.logShown ? body.width - column : body.paneLeft + (body.rest - column) / 2
                width: column
                height: parent.height
                clip: true

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
                    scrollKey: visible ? view.selected : ""
                    decision: view.decision
                    live: view.decisionLive
                    armed: view.armed
                    onLeave: view.keyboardHome.forceActiveFocus()
                }

                BosunDeskPane {
                    id: deskPane

                    anchors.fill: parent
                    visible: view.paneKind === "desk"
                    clearArmed: view.armed === "C"
                    clearByKey: view.armedBy === "key"
                    onCompactClicked: view.compact()
                    onClearClicked: view.clear()
                    onLeave: view.keyboardHome.forceActiveFocus()
                    onOpened: (key, item) => view.select(key, item)
                }

                BosunSessionPane {
                    id: sessionPane

                    anchors.fill: parent
                    visible: view.paneKind === "session" && view.session !== null
                    session: view.session
                    killArmed: view.killing !== "" && view.killing === (view.session?.node ?? "")
                    onKillClicked: view.kill(view.session.node)
                    clearArmed: view.armed === "C"
                    clearByKey: view.armedBy === "key"
                    onCompactClicked: view.compact()
                    onClearClicked: view.clear()
                    onLeave: view.keyboardHome.forceActiveFocus()
                    onDecisionOpened: id => view.select(`decision:${id}`)
                }

                BosunLogPane {
                    id: logPane

                    anchors.fill: parent
                    visible: view.paneKind === "log" && view.logEntry !== null
                    scrollKey: visible ? view.selected : ""
                    entry: view.logEntry
                    onOpened: (key, item) => view.select(key, item)
                }

                BosunSpawnPane {
                    id: spawnPane

                    anchors.fill: parent
                    visible: view.paneKind === "spawn" && Bosun.connected
                    scrollKey: visible ? "spawn" : ""
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
