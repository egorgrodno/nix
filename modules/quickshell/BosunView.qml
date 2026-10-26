pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// The bosun panel's content: the titlebar, a banner while the fleet is
// paused, then the sidebar, and beside it the selected row whole, or the New
// worker form. Keys act only while no text field has focus, which starts in
// the sidebar. Approving, denying and pausing take a second press of the same
// key within three seconds: the first arms and lights the button, and any
// other key or a move disarms it.
Item {
    id: view

    // Where Panel.qml sends the keyboard from a field a press lands outside.
    readonly property Item keyboardHome: sidebar

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

    readonly property string paneKind: {
        if (selected === "spawn")
            return "spawn";
        if (selected === "desk")
            return Bosun.desk ? "desk" : "session";
        return selected.split(":")[0];
    }
    readonly property var decision: {
        if (paneKind !== "decision")
            return null;
        const id = selected.slice("decision:".length);
        return Bosun.mine.find(d => d.id === id) ?? (held?.id === id ? held : null);
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

    function select(key) {
        selected = key;
    }

    function move(step) {
        const keys = sidebar.keys;
        const from = keys.indexOf(selected === "spawn" ? beforeSpawn : selected);
        if (keys.length === 0)
            return;
        select(keys[from < 0 ? 0 : Math.max(0, Math.min(keys.length - 1, from + step))]);
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
        sidebar.forceActiveFocus();
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
        switch (event.key) {
        case Qt.Key_Down:
            move(1);
            return true;
        case Qt.Key_Up:
            move(-1);
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            focusPane();
            return true;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            if (sidebar.activeFocus)
                focusPane();
            else
                sidebar.forceActiveFocus();
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
        }
        return false;
    }

    onSelectedChanged: {
        armed = "";
        killing = "";
        const live = Bosun.mine.find(d => `decision:${d.id}` === selected);
        if (live)
            held = live;
        else if (!held || selected !== `decision:${held.id}`)
            held = null;
        if (selected.startsWith("log:"))
            logEntry = Bosun.log.find(e => `log:${e.seq}` === selected) ?? logEntry;
    }
    Component.onCompleted: {
        select(defaultKey());
        sidebar.forceActiveFocus();
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
            onPauseClicked: view.pause()
            onResumeClicked: Bosun.unpause()
            onNewWorkerClicked: view.selected === "spawn" ? view.closeSpawn() : view.openSpawn()
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

        BosunSidebar {
            id: sidebar

            anchors.top: errorStrip.bottom
            anchors.bottom: parent.bottom
            width: 380
            selected: view.selected
            held: view.held
            onChosen: key => {
                view.select(key);
                sidebar.forceActiveFocus();
            }
            Keys.onPressed: event => event.accepted = view.press(event)
        }

        Rectangle {
            anchors.top: errorStrip.bottom
            anchors.bottom: parent.bottom
            anchors.left: sidebar.right
            width: 1
            color: Theme.tint(0.08)
        }

        Item {
            id: detail

            anchors.top: errorStrip.bottom
            anchors.bottom: parent.bottom
            anchors.left: sidebar.right
            anchors.leftMargin: 1
            anchors.right: parent.right

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
                onLeave: sidebar.forceActiveFocus()
            }

            BosunDeskPane {
                id: deskPane

                anchors.fill: parent
                visible: view.paneKind === "desk"
                onLeave: sidebar.forceActiveFocus()
            }

            BosunSessionPane {
                id: sessionPane

                anchors.fill: parent
                visible: view.paneKind === "session" && view.session !== null
                session: view.session
                killArmed: view.killing !== "" && view.killing === (view.session?.node ?? "")
                onKillClicked: view.kill(view.session.node)
                onLeave: sidebar.forceActiveFocus()
            }

            BosunLogPane {
                id: logPane

                anchors.fill: parent
                visible: view.paneKind === "log" && view.logEntry !== null
                entry: view.logEntry
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
