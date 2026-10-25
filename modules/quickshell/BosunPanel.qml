pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// Under the bosun module: the decisions waiting on the user, each with its
// answer, then those waiting on the master, which the user may answer too,
// then the tree of sessions. A click on a session opens it in a terminal.
Panel {
    id: panel

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

    // What a permission asks to run or touch, as `bosun status` names it.
    function detailOf(decision) {
        const input = decision.input ?? {};
        for (const key of ["command", "file_path", "notebook_path", "url", "pattern"])
            if (typeof input[key] === "string")
                return input[key];
        return JSON.stringify(input);
    }

    function stateOf(session) {
        if (session.killed)
            return "killed";
        if (session.limitedUntil)
            return `limited until ${Qt.formatTime(new Date(session.limitedUntil), "HH:mm")}`;
        return session.state ? `${session.status} · ${session.state}` : session.status;
    }

    // A decision and its answers: Deny and Approve for a permission, a reply
    // field for a question, Dismiss for a notice.
    component DecisionCard: Rectangle {
        id: card

        required property var modelData
        readonly property var decision: modelData

        function send() {
            const text = answer.text.trim();
            if (text === "")
                return;
            Bosun.reply(decision.id, text);
            answer.text = "";
        }

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
                text: card.decision.kind === "permission" ? panel.detailOf(card.decision) : card.decision.kind === "question" ? card.decision.question : card.decision.note
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

            Rectangle {
                width: parent.width
                height: 32
                visible: card.decision.kind === "question"
                radius: Theme.radius - 4
                color: Theme.tint(0.06)
                border.color: answer.activeFocus ? Theme.blue : "transparent"
                border.width: 1

                TextInput {
                    id: answer

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
                    Keys.onReturnPressed: card.send()
                    Keys.onEnterPressed: card.send()

                    BarText {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: answer.text === ""
                        text: "Answer"
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
                    color: answer.text !== "" && sendMouse.containsMouse ? Theme.foregroundStrong : Theme.foregroundMuted

                    MouseArea {
                        id: sendMouse

                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        onClicked: card.send()
                    }
                }
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
            anchors.right: detail.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: row.session.node
            color: row.working ? Theme.blue : row.resting ? Theme.foregroundMuted : Theme.foregroundStrong
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
        spacing: 2

        Caption {
            bottomPadding: 6
            text: Bosun.connected ? "Sessions" : "The bosun daemon is not running"
        }

        Repeater {
            model: panel.tree

            delegate: SessionRow {}
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
