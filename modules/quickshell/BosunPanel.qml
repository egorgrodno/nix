pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io

// Under the bosun module: while the fleet is paused, a banner with Resume, then
// a count of the decisions the master holds, then the decisions waiting on the
// user, each with its answer, then the master's model and a
// field to tell the desk, then the tree of sessions, the desk first. A click on
// a session opens it in a terminal, Kill on a worker stops it, and Pause all stops every session,
// each at a second click. New worker opens a form under the tree that starts
// one under the master. Last, the messages between sessions.
Panel {
    id: panel

    // While the form for a new worker is open.
    property bool spawning: false
    // The worker a first click on Kill armed.
    property string killing: ""
    // While a first click on Pause all has armed it.
    property bool pausing: false
    // Where a new worker may start: each directory Claude Code trusts that
    // holds a repository.
    property var repos: []
    readonly property string home: Quickshell.env("HOME")

    boxWidth: 720

    // The desk first, then depth first, each session under its parent, as
    // `bosun status` prints it.
    readonly property var tree: {
        const children = new Map();
        for (const s of Bosun.sessions.filter(s => s.node !== "desk")) {
            const parent = s.parent ?? "";
            children.set(parent, [...(children.get(parent) ?? []), s]);
        }
        const rows = Bosun.desk ? [Bosun.desk] : [];
        const walk = parent => {
            for (const s of children.get(parent) ?? []) {
                rows.push(s);
                walk(s.node);
            }
        };
        walk("");
        return rows;
    }

    function stateOf(session) {
        if (session.killed)
            return "killed";
        if (session.paused)
            return "paused";
        if (session.limitedUntil)
            return `limited until ${Qt.formatTime(new Date(session.limitedUntil), "HH:mm")}`;
        return session.state ? `${session.status} · ${session.state}` : session.status;
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

    function pause() {
        if (!pausing) {
            pausing = true;
            disarm.restart();
            return;
        }
        pausing = false;
        Bosun.pause();
    }

    function findRepos() {
        claudeState.reload();
        let trusted = [];
        try {
            const projects = JSON.parse(claudeState.text()).projects ?? {};
            trusted = Object.keys(projects).filter(p => projects[p].hasTrustDialogAccepted === true);
        } catch (e) {}
        repoFinder.command = [Programs.sh, "-c", "for d; do [ -e \"$d/.git\" ] && printf '%s\\n' \"$d\"; done", "sh", ...trusted];
        repoFinder.running = true;
    }

    onSpawningChanged: if (spawning)
        findRepos()

    // Claude Code's own state, which records each directory's trust.
    FileView {
        id: claudeState

        path: `${panel.home}/.claude.json`
        blockAllReads: true
        printErrors: false
    }

    Process {
        id: repoFinder

        stdout: StdioCollector {
            onStreamFinished: panel.repos = text.split("\n").filter(p => p !== "").sort()
        }
    }

    Timer {
        id: disarm

        interval: 3000
        onTriggered: {
            panel.killing = "";
            panel.pausing = false;
        }
    }

    // A line of text and a glyph that sends it, as Return does, then clears.
    component SendField: Rectangle {
        id: field

        property string placeholder

        signal sent(string text)

        function send() {
            const text = input.text.trim();
            if (text === "")
                return;
            sent(text);
            input.text = "";
        }

        width: parent?.width ?? 0
        height: 32
        radius: Theme.radius - 4
        color: Theme.tint(0.06)
        border.color: input.activeFocus ? Theme.blue : "transparent"
        border.width: 1

        TextInput {
            id: input

            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.right: sendButton.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            clip: true
            color: Theme.foregroundStrong
            selectionColor: Theme.blue
            selectByMouse: true
            font.family: Theme.fontUI
            font.pixelSize: 14
            font.hintingPreference: Font.PreferFullHinting
            renderType: Text.CurveRendering
            Keys.onReturnPressed: field.send()
            Keys.onEnterPressed: field.send()

            BarText {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: field.placeholder
                color: Theme.foregroundMuted
                font.pixelSize: 14
            }
        }

        BarText {
            id: sendButton

            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: "\u{F048A}"
            color: input.text !== "" && sendMouse.containsMouse ? Theme.foregroundStrong : Theme.foregroundMuted

            MouseArea {
                id: sendMouse

                anchors.fill: parent
                anchors.margins: -6
                hoverEnabled: true
                onClicked: field.send()
            }
        }
    }

    // A part of a call, whole under its label, on a tint that marks what it is.
    component CallBlock: Column {
        id: block

        required property var modelData
        readonly property string kind: modelData.kind
        readonly property bool mono: ["code", "removed", "added"].includes(kind)
        readonly property bool boxed: kind !== "note"

        width: parent?.width ?? 0
        spacing: 4

        Caption {
            visible: block.modelData.label !== ""
            text: block.modelData.label
        }

        Rectangle {
            width: parent.width
            height: blockText.implicitHeight + 2 * blockText.y
            radius: 4
            color: {
                switch (block.kind) {
                case "removed":
                    return Theme.alpha(Theme.red, 0.15);
                case "added":
                    return Theme.alpha(Theme.green, 0.15);
                case "flag":
                    return Theme.alpha(Theme.yellow, 0.15);
                case "note":
                    return "transparent";
                }
                return Theme.tint(0.06);
            }

            BarText {
                id: blockText

                x: block.boxed ? 8 : 0
                y: block.boxed ? 6 : 0
                width: parent.width - 2 * x
                wrapMode: Text.Wrap
                font.family: block.mono ? Theme.fontMono : Theme.fontUI
                font.pixelSize: block.mono ? 13 : 14
                color: block.kind === "flag" ? Theme.yellow : block.kind === "note" ? Theme.foregroundMuted : Theme.foregroundStrong
                text: block.modelData.text
            }
        }
    }

    // A decision and its answers: Deny and Approve for a permission, a reply
    // field for a question, Dismiss for a notice. A permission shows its whole
    // call.
    component DecisionCard: Rectangle {
        id: card

        required property var modelData
        readonly property var decision: modelData

        width: parent?.width ?? 0
        height: body.implicitHeight + 24
        radius: Theme.radius - 4
        color: Theme.tint(0.04)

        Column {
            id: body

            x: 12
            y: 12
            width: parent.width - 24
            spacing: 8

            BarText {
                width: parent.width
                elide: Text.ElideRight
                color: card.decision.reserved ? Theme.yellow : Theme.foregroundMuted
                font.pixelSize: 14
                text: {
                    const d = card.decision;
                    const what = d.kind === "permission" ? d.tool : d.kind === "question" ? "asks" : "says";
                    return [d.node, what].concat(d.reserved ? [`reserved: ${d.reserved}`] : [], d.userOnly ? ["only you may answer"] : []).join(" · ");
                }
            }

            // What auto mode last refused this session.
            BarText {
                width: parent.width
                visible: (card.decision.refused ?? "") !== ""
                wrapMode: Text.Wrap
                color: Theme.yellow
                font.pixelSize: 14
                text: `Refused: ${card.decision.refused ?? ""}`
            }

            BarText {
                width: parent.width
                visible: card.decision.kind !== "permission"
                wrapMode: Text.Wrap
                font.pixelSize: 14
                text: card.decision.kind === "question" ? card.decision.question : card.decision.note ?? ""
            }

            Repeater {
                model: card.decision.kind === "permission" ? Bosun.callOf(card.decision) : []

                delegate: CallBlock {}
            }

            // Why the master escalated it.
            BarText {
                width: parent.width
                visible: card.decision.kind !== "notice" && (card.decision.note ?? "") !== ""
                wrapMode: Text.Wrap
                color: Theme.foregroundMuted
                font.pixelSize: 14
                text: `Master: ${card.decision.note ?? ""}`
            }

            Row {
                anchors.right: parent.right
                visible: card.decision.kind !== "question"
                spacing: 6

                TextButton {
                    visible: card.decision.kind === "permission"
                    text: "Deny"
                    hoverFill: Theme.alpha(Theme.red, 0.5)
                    onClicked: Bosun.deny(card.decision.id)
                }

                TextButton {
                    visible: card.decision.kind === "permission"
                    text: "Approve"
                    hoverFill: Theme.alpha(Theme.blue, 0.5)
                    onClicked: Bosun.approve(card.decision.id)
                }

                TextButton {
                    visible: card.decision.kind === "notice"
                    text: "Dismiss"
                    onClicked: Bosun.dismiss(card.decision.id)
                }
            }

            SendField {
                visible: card.decision.kind === "question"
                placeholder: "Answer"
                onSent: text => Bosun.reply(card.decision.id, text)
            }
        }
    }

    // A session, indented under its parent: blue in its turn, faint once
    // stopped. A click attaches to it.
    component SessionRow: Item {
        id: row

        required property var modelData
        readonly property var session: modelData
        readonly property bool attachable: (session.id ?? "") !== "" && session.status !== "exited"
        readonly property bool killable: attachable && !["master", "desk"].includes(session.node) && session.killed !== true
        readonly property bool armed: panel.killing === session.node
        readonly property bool working: session.status === "busy" || session.status === "waiting"
        readonly property bool resting: ["stopped", "exited"].includes(session.status) || session.killed === true

        width: parent?.width ?? 0
        height: 32

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius - 4
            color: row.attachable && hover.hovered ? Theme.tint(0.07) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }
        }

        HoverHandler {
            id: hover
        }

        MouseArea {
            anchors.fill: parent
            enabled: row.attachable
            onClicked: Bosun.attach(row.session)
        }

        BarText {
            anchors.left: parent.left
            anchors.leftMargin: 8 + 16 * (row.session.depth ?? 0)
            anchors.right: killButton.visible ? killButton.left : detail.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: row.session.node
            color: row.working ? Theme.blue : row.resting ? Theme.foregroundMuted : Theme.foregroundStrong
        }

        TextButton {
            id: killButton

            anchors.right: detail.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            visible: row.killable && (hover.hovered || row.armed)
            text: row.armed ? `Kill ${row.session.node}?` : "Kill"
            hoverFill: Theme.alpha(Theme.red, 0.5)
            lit: row.armed
            onClicked: panel.kill(row.session.node)
        }

        BarText {
            id: detail

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: [panel.stateOf(row.session)].concat(row.session.model ? [row.session.model] : []).join(" · ")
            color: row.session.paused === true ? Theme.yellow : Theme.foregroundMuted
            font.pixelSize: 14
        }
    }

    // A message between sessions, its first line beside who sent it to whom,
    // or under them the whole of it, which a click toggles.
    component MessageRow: Item {
        id: message

        required property var modelData
        property bool expanded: false

        width: parent?.width ?? 0
        height: body.y + body.height + 6

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius - 4
            color: messageHover.hovered ? Theme.tint(0.07) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }
        }

        HoverHandler {
            id: messageHover
        }

        TapHandler {
            onTapped: message.expanded = !message.expanded
        }

        BarText {
            id: names

            x: 8
            y: 6
            width: Math.min(implicitWidth, parent.width - 16)
            elide: Text.ElideRight
            text: `${message.modelData.from} → ${message.modelData.node}`
            color: Theme.foregroundMuted
            font.pixelSize: 14
        }

        BarText {
            id: body

            x: message.expanded ? 8 : names.x + names.width + 8
            y: message.expanded ? names.y + names.height + 2 : names.y
            width: parent.width - x - 8
            wrapMode: message.expanded ? Text.Wrap : Text.NoWrap
            maximumLineCount: message.expanded ? 30 : 1
            elide: Text.ElideRight
            text: message.expanded ? message.modelData.text : message.modelData.text.split("\n")[0]
            font.pixelSize: 14
        }
    }

    // All but the error, scrolling once taller than the strip between the
    // bars leaves, with a bar that shows there is more.
    Flickable {
        id: scroller

        readonly property real limit: (panel.screen?.height ?? 800) - 2 * (Theme.barHeight + Theme.outerGap) - 2 * panel.padding - (errorText.visible ? errorText.height + 20 : 0)

        width: panel.contentWidth
        height: Math.min(contentHeight, limit)
        contentHeight: sections.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            policy: scroller.interactive ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff

            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: Theme.tint(0.25)
            }
        }

        Column {
            id: sections

            width: scroller.width - (scroller.interactive ? 14 : 0)
            spacing: 20

            Rectangle {
                width: parent.width
                height: Math.max(pausedText.implicitHeight, resumeButton.height) + 24
                visible: Bosun.paused
                radius: Theme.radius - 4
                color: Theme.alpha(Theme.yellow, 0.15)

                BarText {
                    id: pausedText

                    x: 12
                    anchors.verticalCenter: parent.verticalCenter
                    width: resumeButton.x - x - 12
                    wrapMode: Text.Wrap
                    color: Theme.yellow
                    font.pixelSize: 14
                    text: {
                        if (Bosun.fleetOp === "pause")
                            return "Pausing: stopping every session";
                        const turns = Bosun.sessions.filter(s => s.paused).map(s => s.node);
                        return turns.length > 0 ? `Paused. Resume restarts the turns of ${turns.join(", ")}.` : "Paused. No session was in its turn.";
                    }
                }

                TextButton {
                    id: resumeButton

                    anchors.right: parent.right
                    anchors.rightMargin: 12
                    anchors.verticalCenter: parent.verticalCenter
                    enabled: Bosun.fleetOp === ""
                    text: "Resume"
                    hoverFill: Theme.alpha(Theme.blue, 0.5)
                    onClicked: Bosun.unpause()
                }
            }

            // Only a count: the master answers these, and the user only the ones it
            // escalates.
            Caption {
                visible: Bosun.masters.length > 0
                text: `${Bosun.masters.length} with the master`
            }

            Column {
                width: parent.width
                visible: Bosun.mine.length > 0
                spacing: 8

                Caption {
                    text: "Waiting on you"
                }

                Repeater {
                    // By id, so a reply being typed survives other decisions coming and going.
                    model: ScriptModel {
                        values: Bosun.mine
                        objectProp: "id"
                    }

                    delegate: DecisionCard {}
                }
            }

            Column {
                width: parent.width
                visible: Bosun.connected
                spacing: 8

                Item {
                    width: parent.width
                    height: modelRow.height

                    Caption {
                        readonly property string model: Bosun.master?.model ?? ""

                        anchors.verticalCenter: parent.verticalCenter
                        text: Bosun.models.includes(model) ? "Master" : `Master · ${model || "default model"}`
                    }

                    Row {
                        id: modelRow

                        anchors.right: parent.right
                        spacing: 6

                        Repeater {
                            model: Bosun.models

                            TextButton {
                                required property string modelData

                                text: modelData
                                lit: modelData === Bosun.master?.model
                                hoverFill: lit ? Theme.blue : Theme.tint(0.12)
                                textColor: lit ? Theme.backgroundMain : Theme.foregroundStrong
                                onClicked: if (!lit)
                                    Bosun.model(modelData)
                            }
                        }
                    }
                }

                SendField {
                    placeholder: Bosun.desk ? "Tell the desk" : "Tell the master"
                    onSent: text => Bosun.tell(text)
                }
            }

            Column {
                width: parent.width
                spacing: 2

                Item {
                    width: parent.width
                    height: sessionButtons.height + 6

                    Caption {
                        anchors.verticalCenter: sessionButtons.verticalCenter
                        text: Bosun.connected ? "Sessions" : "The bosun daemon is not running"
                    }

                    Row {
                        id: sessionButtons

                        anchors.right: parent.right
                        visible: Bosun.connected
                        spacing: 6

                        TextButton {
                            visible: !Bosun.paused
                            enabled: Bosun.fleetOp === ""
                            text: Bosun.fleetOp === "unpause" ? "Resuming…" : panel.pausing ? "Pause every session?" : "Pause all"
                            hoverFill: Theme.alpha(Theme.yellow, 0.5)
                            lit: panel.pausing
                            onClicked: panel.pause()
                        }

                        TextButton {
                            text: "New worker"
                            lit: panel.spawning
                            onClicked: panel.spawning = !panel.spawning
                        }
                    }
                }

                Repeater {
                    model: panel.tree

                    delegate: SessionRow {}
                }
            }

            // It stays until the daemon has started the worker, keeping what was
            // typed through a failed spawn.
            Column {
                id: form

                property string repo: ""
                property string model: ""
                property bool waiting: false
                readonly property bool valid: /^[a-z0-9][a-z0-9-]{0,39}$/.test(nameField.text) && repo !== "" && promptField.text.trim() !== ""

                function start() {
                    if (!valid || waiting)
                        return;
                    waiting = true;
                    Bosun.spawn(nameField.text, repo, promptField.text.trim(), model);
                }

                width: parent.width
                visible: panel.spawning && Bosun.connected
                spacing: 8

                Connections {
                    target: Bosun

                    function onFinished(args, ok) {
                        if (args[0] !== "spawn" || !form.waiting)
                            return;
                        form.waiting = false;
                        if (!ok)
                            return;
                        nameField.text = "";
                        promptField.text = "";
                        form.repo = "";
                        form.model = "";
                        panel.spawning = false;
                    }
                }

                Caption {
                    text: "New worker"
                }

                TextField {
                    id: nameField

                    width: parent.width
                    height: 32
                    leftPadding: 10
                    rightPadding: 10
                    topPadding: 0
                    bottomPadding: 0
                    verticalAlignment: TextInput.AlignVCenter
                    placeholderText: "Name: lowercase letters, digits and hyphens"
                    placeholderTextColor: Theme.foregroundMuted
                    color: Theme.foregroundStrong
                    selectionColor: Theme.blue
                    selectedTextColor: Theme.backgroundMain
                    font.family: Theme.fontUI
                    font.pixelSize: 14
                    onAccepted: promptField.forceActiveFocus()

                    background: Rectangle {
                        radius: Theme.radius - 4
                        color: Theme.tint(0.06)
                        border.width: 1
                        border.color: nameField.activeFocus ? Theme.blue : Theme.tint(0.12)
                    }
                }

                Caption {
                    text: panel.repos.length > 0 ? "In a repository Claude Code trusts" : "Claude Code trusts no repository: run claude in one first"
                }

                Flow {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: panel.repos

                        TextButton {
                            required property string modelData

                            text: modelData.startsWith(`${panel.home}/`) ? `~${modelData.slice(panel.home.length)}` : modelData
                            lit: modelData === form.repo
                            hoverFill: lit ? Theme.blue : Theme.tint(0.12)
                            textColor: lit ? Theme.backgroundMain : Theme.foregroundStrong
                            onClicked: form.repo = modelData
                        }
                    }
                }

                Caption {
                    text: "On a model"
                }

                Flow {
                    width: parent.width
                    spacing: 6

                    Repeater {
                        model: [""].concat(Bosun.models)

                        TextButton {
                            required property string modelData

                            text: modelData === "" ? "Default" : modelData
                            lit: modelData === form.model
                            hoverFill: lit ? Theme.blue : Theme.tint(0.12)
                            textColor: lit ? Theme.backgroundMain : Theme.foregroundStrong
                            onClicked: form.model = modelData
                        }
                    }
                }

                TextArea {
                    id: promptField

                    width: parent.width
                    padding: 10
                    wrapMode: TextEdit.Wrap
                    placeholderText: "Its task"
                    placeholderTextColor: Theme.foregroundMuted
                    color: Theme.foregroundStrong
                    selectionColor: Theme.blue
                    selectedTextColor: Theme.backgroundMain
                    font.family: Theme.fontUI
                    font.pixelSize: 14
                    Keys.onPressed: event => {
                        if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && event.modifiers & Qt.ControlModifier) {
                            form.start();
                            event.accepted = true;
                        }
                    }

                    background: Rectangle {
                        radius: Theme.radius - 4
                        color: Theme.tint(0.06)
                        border.width: 1
                        border.color: promptField.activeFocus ? Theme.blue : Theme.tint(0.12)
                    }
                }

                Item {
                    width: parent.width
                    height: startButton.height

                    Caption {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "Ctrl Enter starts it"
                        font.pixelSize: 12
                    }

                    Row {
                        anchors.right: parent.right
                        spacing: 6

                        TextButton {
                            text: "Cancel"
                            onClicked: panel.spawning = false
                        }

                        TextButton {
                            id: startButton

                            enabled: form.valid && !form.waiting
                            text: form.waiting ? "Starting…" : "Start"
                            hoverFill: Theme.alpha(Theme.blue, 0.5)
                            onClicked: form.start()
                        }
                    }
                }
            }

            Column {
                width: parent.width
                visible: Bosun.messages.length > 0
                spacing: 2

                Caption {
                    bottomPadding: 6
                    text: "Messages"
                }

                Repeater {
                    // By reference, so a message opened stays open as newer ones come.
                    model: ScriptModel {
                        values: Bosun.messages
                    }

                    delegate: MessageRow {}
                }
            }
        }
    }

    BarText {
        id: errorText

        width: panel.contentWidth
        visible: Bosun.error !== ""
        wrapMode: Text.Wrap
        color: Theme.yellow
        font.pixelSize: 14
        text: Bosun.error
    }
}
