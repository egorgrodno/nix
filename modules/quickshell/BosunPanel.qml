pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io

// Under the bosun module: the decisions waiting on the user, each with its
// answer, then those waiting on the master, which the user may answer too,
// then the master's model and a field to tell it, then the tree of sessions.
// A click on a session opens it in a terminal, and Kill on a worker stops it,
// at a second click. New worker opens a form under the tree that starts one
// under the master. Last, the messages between sessions.
Panel {
    id: panel

    // While the form for a new worker is open.
    property bool spawning: false
    // The worker a first click on Kill armed.
    property string killing: ""
    // Where a new worker may start: each directory Claude Code trusts that
    // holds a repository.
    property var repos: []
    readonly property string home: Quickshell.env("HOME")

    boxWidth: 440

    // Depth first, each session under its parent, as `bosun status` prints it.
    readonly property var tree: {
        const children = new Map();
        for (const s of Bosun.sessions) {
            const parent = s.parent ?? "";
            children.set(parent, [...(children.get(parent) ?? []), s]);
        }
        const rows = [];
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
        onTriggered: panel.killing = ""
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

    // A decision and its answers: Deny and Approve for a permission, a reply
    // field for a question, Dismiss for a notice.
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
                    return [d.node, what].concat(d.reserved ? [d.reserved] : []).join(" · ");
                }
            }

            BarText {
                width: parent.width
                wrapMode: Text.Wrap
                maximumLineCount: 8
                elide: Text.ElideRight
                font.family: card.decision.kind === "permission" ? Theme.fontMono : Theme.fontUI
                font.pixelSize: 14
                text: card.decision.kind === "permission" ? Bosun.detailOf(card.decision) : card.decision.kind === "question" ? card.decision.question : card.decision.note
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
        readonly property bool killable: attachable && session.node !== "master" && session.killed !== true
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
            color: Theme.foregroundMuted
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

    Column {
        width: panel.contentWidth
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
        width: panel.contentWidth
        visible: Bosun.masters.length > 0
        spacing: 8

        Caption {
            text: "Waiting on the master"
        }

        Repeater {
            model: ScriptModel {
                values: Bosun.masters
                objectProp: "id"
            }

            delegate: DecisionCard {}
        }
    }

    Column {
        width: panel.contentWidth
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
            placeholder: "Tell the master"
            onSent: text => Bosun.tell(text)
        }
    }

    Column {
        width: panel.contentWidth
        spacing: 2

        Item {
            width: parent.width
            height: newButton.height + 6

            Caption {
                anchors.verticalCenter: newButton.verticalCenter
                text: Bosun.connected ? "Sessions" : "The bosun daemon is not running"
            }

            TextButton {
                id: newButton

                anchors.right: parent.right
                visible: Bosun.connected
                text: "New worker"
                lit: panel.spawning
                onClicked: panel.spawning = !panel.spawning
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

        width: panel.contentWidth
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
        width: panel.contentWidth
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

    BarText {
        width: panel.contentWidth
        visible: Bosun.error !== ""
        wrapMode: Text.Wrap
        color: Theme.yellow
        font.pixelSize: 14
        text: Bosun.error
    }
}
