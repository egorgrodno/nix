pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// The bosun panel's content: the titlebar, a banner while the fleet is
// paused, then the sidebar, and beside it the selected row whole, or the New
// worker form. Expanded to the work area, the sidebar shrinks to a rail of its
// sections, which can show the sidebar beside it again. There the Log becomes
// a table with the selected entry whole beside it, and any other pane keeps to
// a column narrow enough to read. Keys act only while no text field has
// focus, which starts in the sidebar, and Ctrl+C copies the text the mouse
// selected, which never takes it. Approving, denying, pausing and clearing a
// conversation by key take a second press of the same key within three
// seconds, and so do Pause, Kill and Clear by click: the first arms and lights
// the button, and any other key or a move disarms it. Approve and Deny act on
// a single click.
Item {
    id: view

    // Where Panel.qml sends the keyboard from a field a press lands outside:
    // the list beside the pane.
    readonly property Item keyboardHome: logShown ? logTable : sidebar.visible ? sidebar : rail

    // BosunKept holds what the panel shows, so it opens where it closed.
    readonly property string selected: BosunKept.selected
    readonly property var held: BosunKept.held
    readonly property bool expanded: BosunKept.expanded
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

    function setExpanded(on) {
        BosunKept.expanded = on;
        following.restart();
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

    // The composer with the keyboard, for BosunComposer to take it back when
    // the panel opens again.
    function keepField() {
        let item = view.Window.activeFocusItem;
        while (item && item.draftKey === undefined)
            item = item.parent;
        BosunKept.typing = item ? {
            key: item.draftKey,
            cursor: item.cursor
        } : null;
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

    function kill(node) {
        if (killing !== node) {
            killing = node;
            disarm.restart();
            return;
        }
        killing = "";
        Bosun.kill(node);
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
        // Out of the expanded size, else on to Panel.qml, which closes.
        case Qt.Key_Escape:
            if (!expanded)
                return false;
            setExpanded(false);
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
            return live === "permission" && twice("y", was, () => decisionPane.approve());
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
            return true;
        case "n":
            openSpawn();
            return true;
        case "p":
            if (!Bosun.connected || Bosun.fleetOp !== "")
                return false;
            return twice("p", was, () => Bosun.paused ? Bosun.unpause() : Bosun.pause());
        case "m":
            return currentPane()?.openModel?.() ?? false;
        case "c":
            if (!Bosun.connected || contextNode === "")
                return false;
            compact();
            return true;
        case "C":
            return clearable && twice("C", was, clearNow);
        case "f":
            setExpanded(!expanded);
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
        Bosun.panelsOpen++;
        if (selected === "")
            select(defaultKey());
        keyboardHome.forceActiveFocus();
    }
    Component.onDestruction: {
        Bosun.panelsOpen--;
        BosunKept.save();
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
                sidebarShown: BosunKept.sidebarShown
                onPicked: name => view.openSection(name)
                onSidebarToggled: BosunKept.sidebarShown = !BosunKept.sidebarShown
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
                visible: !view.expanded || BosunKept.sidebarShown
                expanded: view.expanded
                selected: view.selected
                held: view.paneKind === "decision" ? view.decision : null
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

            // The selected row whole: beside the Log's table at about a third
            // of what the panel leaves, as the mockup has it, else in that, at
            // most 1200 wide.
            Item {
                id: detail

                readonly property real column: view.logShown ? Math.round(body.rest * 0.35) : view.expanded ? Math.min(body.rest, 1200) : body.rest

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
