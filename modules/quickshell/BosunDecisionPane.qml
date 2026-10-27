pragma ComponentBehavior: Bound

import QtQuick

// A decision whole: why the master passed it on, what reserves it and what
// auto mode refused, the call or the question, and its answers. A permission
// takes Deny, with a note of what to do instead, and Approve, a question a
// reply, a notice Dismiss. Once settled it stays, faded and unanswerable,
// until the selection moves, and no longer says what reserved it.
BosunPane {
    id: pane

    // The decision, live or held.
    property var decision: null
    // While it still waits on the user.
    property bool live: false
    // "a" or "d" while a first press has armed Approve or Deny.
    property string armed: ""
    readonly property string decisionId: decision?.id ?? ""
    readonly property string kind: decision ? Bosun.kindOf(decision) : ""
    readonly property var session: Bosun.sessions.find(s => s.node === decision?.node) ?? null
    // What the header's age counts from.
    property real now: Date.now()
    // Who settled it, how and when: "Allowed by the master at 17:44."
    readonly property string settledText: {
        if (live || !decision)
            return "";
        if (Bosun.masters.some(d => d.id === decisionId))
            return "The master is deciding it, and passes it to you only if it needs you.";
        const entry = Bosun.settledEntry(decisionId);
        const outcome = entry ? BosunLook.outcomeOf(entry) : "";
        const at = entry?.at ? ` at ${Qt.formatTime(new Date(entry.at), "HH:mm")}` : "";
        const by = {
            user: "you",
            master: "the master",
            desk: "the desk",
            bosun: "bosun"
        }[entry?.by] ?? entry?.from ?? "";
        const outcomeWord = outcome.charAt(0).toUpperCase() + outcome.slice(1);
        let text = "It no longer waits on you.";
        if (outcome === "withdrawn")
            text = `Withdrawn${at}${entry.cause ? `, when ${entry.cause}` : ""}.`;
        else if (entry?.by === "session")
            text = `${outcomeWord} in ${decision.node}'s own prompt${at}.`;
        else if (entry) {
            const said = entry.text ? `: “${entry.text}”` : "";
            const word = entry.by === "desk" && entry.words ? `, on your word “${entry.words}”` : "";
            text = `${outcomeWord} by ${by}${at}${word}${said}`;
            if (!text.endsWith("”"))
                text += ".";
        }
        return text;
    }

    // Back to the sidebar, from a field.
    signal leave

    function approve() {
        if (live && kind === "permission")
            Bosun.approve(decisionId);
    }

    function deny() {
        if (live && kind === "permission")
            Bosun.deny(decisionId, noteField.text.trim());
    }

    function focusNote() {
        if (live && kind === "permission")
            noteField.focusIn();
    }

    function focusReply() {
        if (live && kind === "question")
            replyField.focusIn();
    }

    // Where Tab and Enter take the keyboard: the field this decision takes.
    function focusIn() {
        if (kind === "question")
            focusReply();
        else
            focusNote();
        return live && kind !== "notice";
    }

    title: {
        const d = decision;
        if (!d)
            return "";
        if (kind === "question")
            return `${d.node} asks`;
        if (kind === "notice")
            return `${d.node} says`;
        switch (d.tool) {
        case "Bash":
            return `${d.node} wants to run a command`;
        case "Edit":
        case "MultiEdit":
            return `${d.node} wants to edit a file`;
        case "Write":
            return `${d.node} wants to write a file`;
        case "NotebookEdit":
            return `${d.node} wants to edit a notebook`;
        }
        return `${d.node} wants to use ${d.tool}`;
    }
    aside: decision ? `#${decision.id}` : ""
    facts: [
        BosunFact {
            glyph: BosunLook.clock
            text: BosunLook.ago(Bosun.askedAt(pane.decision), pane.now)
        },
        BosunFact {
            glyph: BosunLook.folder
            text: BosunLook.tilde(pane.session?.repo || pane.session?.dir)
        },
        BosunFact {
            glyph: BosunLook.branch
            text: pane.session?.base ? `worktree-${pane.session.node}` : ""
        },
        BosunFact {
            glyph: BosunLook.chip
            text: [pane.session?.model, pane.session?.effort].filter(part => part).join(" ")
        }
    ]

    // Milliseconds until the daemon leaves the decision to the session's own
    // prompt, or -1 when it has no deadline or no longer waits.
    readonly property real remaining: live ? BosunLook.untilExpiry(decision, now) : -1

    // Ticks the header's age, and every second the last two minutes of a
    // countdown.
    Timer {
        running: pane.visible
        interval: pane.remaining >= 0 && pane.remaining < 120000 ? 1000 : 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: pane.now = Date.now()
    }

    Banner {
        visible: pane.settledText !== ""
        glyph: BosunLook.notice
        tint: Theme.foregroundMuted
        text: pane.settledText
    }

    Banner {
        visible: pane.remaining >= 0
        glyph: BosunLook.clock
        tint: pane.remaining < 300000 ? Theme.red : pane.remaining < 900000 ? Theme.yellow : Theme.foregroundMuted
        text: pane.remaining > 0 ? `Falls back to ${pane.decision?.node ?? "the session"}'s own prompt in ${BosunLook.countdown(pane.remaining)}. Nobody sees that prompt in a background session.` : `Now left to ${pane.decision?.node ?? "the session"}'s own prompt. Nobody sees that prompt in a background session.`
    }

    // Why the master passed it on, first: it may say the decision needs no
    // answer. A notice's note is its text.
    Rectangle {
        width: parent.width
        visible: pane.decision?.kind !== "notice" && (pane.decision?.note ?? "") !== ""
        height: noteColumn.implicitHeight + 24
        radius: Theme.radius - 4
        color: Theme.alpha(Theme.blue, 0.12)
        border.width: 1
        border.color: Theme.alpha(Theme.blue, 0.4)
        opacity: pane.live ? 1 : 0.6

        Column {
            id: noteColumn

            x: 12
            y: 12
            width: parent.width - 2 * x
            spacing: 6

            BosunFact {
                glyph: BosunLook.master
                glyphColor: Theme.blue
                text: "Why the master passed it to you"
            }

            BarText {
                width: parent.width
                wrapMode: Text.Wrap
                font.pixelSize: 16
                text: pane.decision?.note ?? ""
            }
        }
    }

    Banner {
        visible: pane.live && (pane.decision?.reserved ?? "") !== ""
        glyph: BosunLook.reserved
        tint: Theme.yellow
        text: `Reserved: ${pane.decision?.reserved ?? ""}.${pane.decision?.userOnly ? " Only your own answer here settles it." : ""}`
    }

    Banner {
        visible: (pane.decision?.refused ?? "") !== ""
        glyph: BosunLook.alert
        tint: Theme.yellow
        text: `Auto mode refused its last call: ${pane.decision?.refused ?? ""}`
    }

    Column {
        width: parent.width
        spacing: 12
        opacity: pane.live ? 1 : 0.6

        BarText {
            width: parent.width
            visible: pane.kind === "question" || pane.decision?.kind === "notice"
            wrapMode: Text.Wrap
            font.pixelSize: 16
            text: (pane.kind === "question" ? pane.decision?.question : pane.decision?.note) ?? ""
        }

        Repeater {
            model: pane.kind === "permission" ? Bosun.callOf(pane.decision) : []

            delegate: BosunCallBlock {}
        }
    }

    foot: [
        Row {
            width: parent.width
            visible: pane.live && pane.kind === "permission"
            spacing: 8

            BosunComposer {
                id: noteField

                width: parent.width - denyButton.width - approveButton.width - 2 * parent.spacing
                height: 34
                sendGlyph: false
                placeholder: "Deny with what to do instead (optional)"
                draftKey: pane.decisionId ? "deny:" + pane.decisionId : ""
                onSent: pane.deny()
                onLeave: pane.leave()
            }

            TextButton {
                id: denyButton

                anchors.verticalCenter: parent.verticalCenter
                height: 34
                text: pane.armed === "d" ? `${BosunLook.close}  Deny?` : `${BosunLook.close}  Deny`
                hoverFill: Theme.alpha(Theme.red, 0.5)
                lit: pane.armed === "d"
                onClicked: pane.deny()
            }

            TextButton {
                id: approveButton

                anchors.verticalCenter: parent.verticalCenter
                height: 34
                text: pane.armed === "a" ? `${BosunLook.check}  Approve?` : `${BosunLook.check}  Approve`
                hoverFill: Theme.alpha(Theme.blue, 0.5)
                lit: pane.armed === "a"
                onClicked: pane.approve()
            }
        },
        BosunComposer {
            id: replyField

            width: parent.width
            visible: pane.live && pane.kind === "question"
            placeholder: `Answer ${pane.decision?.node ?? ""}`
            draftKey: pane.decisionId ? "reply:" + pane.decisionId : ""
            onSent: text => Bosun.reply(pane.decisionId, text)
            onLeave: pane.leave()
        },
        TextButton {
            anchors.right: parent.right
            visible: pane.live && pane.kind === "notice"
            text: "Dismiss"
            onClicked: Bosun.dismiss(pane.decisionId)
        },
        BosunHints {
            model: {
                const move = {
                    keys: ["j", "k"],
                    text: "next decision"
                };
                if (!pane.live)
                    return [move];
                if (pane.kind === "permission")
                    return [
                        {
                            keys: ["a", "a"],
                            text: "approve"
                        },
                        {
                            keys: ["d", "d"],
                            text: "deny"
                        },
                        {
                            keys: ["D"],
                            text: "deny with a note"
                        },
                        {
                            keys: ["Tab"],
                            text: "write a note"
                        },
                        move];
                if (pane.kind === "question")
                    return [
                        {
                            keys: ["r"],
                            text: "answer"
                        },
                        {
                            keys: ["Ctrl", "Enter"],
                            text: "send"
                        },
                        move];
                return [move];
            }
        }
    ]

    // A line on a tint of its colour, under a glyph.
    component Banner: Rectangle {
        id: banner

        property string glyph
        property color tint
        property string text

        width: parent?.width ?? 0
        height: bannerText.implicitHeight + 20
        radius: Theme.radius - 4
        color: Theme.alpha(tint, 0.12)

        BarText {
            id: bannerGlyph

            x: 12
            y: 10
            text: banner.glyph
            color: banner.tint
            font.pixelSize: 14
        }

        BarText {
            id: bannerText

            anchors.left: bannerGlyph.right
            anchors.leftMargin: 10
            y: 10
            width: parent.width - x - 12
            wrapMode: Text.Wrap
            text: banner.text
            color: banner.tint
            font.pixelSize: 14
        }
    }
}
