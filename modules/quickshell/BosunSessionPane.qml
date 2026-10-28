pragma ComponentBehavior: Bound

import QtQuick

// A session: its state, repository, branch and parent, its conversation, and
// a composer that sends as the user, or tells the master while there is no
// desk. The master's and the desk's model and effort switch beside Interrupt,
// Kill for a worker at a second click, and Open in kitty, which attaches to
// it. A session gone from the fleet keeps what it showed, and offers nothing.
BosunPane {
    id: pane

    required property var session
    // While a first click has armed Kill.
    property bool killArmed: false
    readonly property string node: session?.node ?? ""
    readonly property bool gone: session !== null && !Bosun.sessions.some(s => s.node === node)
    readonly property bool attachable: !gone && (session?.id ?? "") !== "" && session?.status !== "exited"
    readonly property bool killable: attachable && !["master", "desk"].includes(node) && session?.killed !== true
    // The daemon's `model` switches only these.
    readonly property bool switchable: !gone && ["master", "desk"].includes(node) && Bosun.connected
    readonly property bool sayable: attachable && session?.killed !== true && Bosun.connected
    // A tell queues in the daemon and outlasts a pause, which a say does not.
    readonly property bool tells: node === "master" && !Bosun.desk && !gone && Bosun.connected
    readonly property string stateKey: session ? BosunLook.stateOf(session) : "stopped"
    readonly property alias conversation: conversationView

    // While a first press or click has armed Clear, and which armed it.
    property bool clearArmed: false
    property bool clearByKey: false
    readonly property bool contextual: node === "master" && !gone && Bosun.connected

    signal killClicked
    signal compactClicked
    signal clearClicked
    signal leave
    signal decisionOpened(string id)

    function focusIn() {
        if (!composer.visible)
            return false;
        composer.focusIn();
        return true;
    }

    // Opens the model menu, for the panel's `m`; false while there is none.
    function openModel() {
        return modelMenu.show();
    }

    title: node
    actions: [
        BosunDropdown {
            id: modelMenu

            name: "Model"
            after: effortMenu
            visible: pane.switchable
            enabled: Bosun.switching !== pane.node
            values: Bosun.models
            current: pane.session?.model ?? ""
            fallback: "default"
            fallbackLabel: pane.session?.runs?.modelName ? `Default (${pane.session.runs.modelName})` : "Default"
            onPicked: value => Bosun.model(pane.node, value, "")
        },
        BosunDropdown {
            id: effortMenu

            name: "Effort"
            visible: pane.switchable
            enabled: Bosun.switching !== pane.node
            values: Bosun.efforts
            current: pane.session?.effort ?? ""
            fallback: "default"
            fallbackLabel: pane.session?.runs?.effort ? `Default (${pane.session.runs.effort})` : "Default"
            onPicked: value => Bosun.model(pane.node, "", value)
        },
        TextButton {
            visible: conversationView.inTurn && pane.sayable
            text: `${BosunLook.interrupt}  Interrupt`
            onClicked: Bosun.interrupt(pane.node)
        },
        TextButton {
            visible: pane.killable
            text: pane.killArmed ? `${BosunLook.states.killed.glyph}  Click again to kill` : `${BosunLook.states.killed.glyph}  Kill`
            hoverFill: Theme.alpha(Theme.red, 0.5)
            lit: pane.killArmed
            onClicked: pane.killClicked()
        },
        TextButton {
            visible: pane.attachable
            text: `${BosunLook.open}  Open in kitty`
            onClicked: Bosun.attach(pane.session)
        }
    ]
    facts: [
        BosunFact {
            glyph: BosunLook.states[pane.gone ? "stopped" : pane.stateKey].glyph
            glyphColor: pane.gone ? Theme.foregroundMuted : BosunLook.stateColor(pane.stateKey)
            text: pane.gone ? "Gone from the fleet" : pane.session ? BosunLook.stateWords(pane.session) : ""
        },
        BosunFact {
            glyph: BosunLook.folder
            text: BosunLook.tilde(pane.session?.repo || pane.session?.dir)
        },
        BosunFact {
            glyph: BosunLook.branch
            text: pane.session?.base ? `worktree-${pane.node}` : ""
        },
        // A worker's model, which only its parent switches.
        BosunFact {
            visible: !pane.switchable && text !== ""
            glyph: BosunLook.chip
            text: [pane.session?.model, pane.session?.effort].filter(part => part).join(" ") || (pane.session ? "default model" : "")
        },
        BosunContext {
            context: pane.session?.context ?? null
        },
        BosunContextActions {
            node: "master"
            visible: pane.contextual
            clearArmed: pane.clearArmed
            clearByKey: pane.clearByKey
            onCompactClicked: pane.compactClicked()
            onClearClicked: pane.clearClicked()
        },
        BosunFact {
            glyph: BosunLook.account
            text: pane.session?.parent ? `spawned by ${pane.session.parent}` : ""
        }
    ]

    fill: [
        BosunConversation {
            id: conversationView

            anchors.fill: parent
            node: pane.visible ? pane.node : ""
            scrollKey: conversationView.node !== "" ? `session:${conversationView.node}` : ""
            parentNode: pane.session?.parent ?? ""
            live: !pane.gone
            status: pane.session?.status ?? ""
            onDecisionOpened: id => pane.decisionOpened(id)
        }
    ]

    foot: [
        BosunComposer {
            id: composer

            width: parent.width
            visible: pane.tells || pane.sayable
            suggestion: conversationView.feed.suggestion
            draftKey: pane.tells ? "tell:master" : `say:${pane.node}`
            onSent: text => pane.tells ? Bosun.tell(text) : Bosun.say(pane.node, text)
            onLeave: pane.leave()
        },
        BosunHints {
            model: {
                const hints = [];
                if (composer.visible)
                    hints.push({
                        keys: ["Ctrl", "Enter"],
                        text: "send"
                    }, {
                        keys: ["Esc"],
                        text: "back to the list"
                    });
                if (composer.suggesting)
                    hints.push({
                        keys: ["Tab"],
                        text: "accept the suggested reply"
                    });
                if (composer.visible && !pane.tells)
                    hints.push({
                        keys: ["/"],
                        text: "commands such as /compact"
                    });
                if (pane.switchable)
                    hints.push({
                        keys: ["m"],
                        text: "model and effort"
                    });
                if (pane.contextual) {
                    hints.push({
                        keys: ["c"],
                        text: "compact"
                    });
                    if (!Bosun.hasWorkers)
                        hints.push({
                            keys: ["C", "C"],
                            text: "clear"
                        });
                }
                return hints.concat([
                    {
                        keys: [Host.directions.down, Host.directions.up],
                        text: "move"
                    },
                    {
                        keys: ["n"],
                        text: "new worker"
                    }
                ]);
            }
        }
    ]
}
