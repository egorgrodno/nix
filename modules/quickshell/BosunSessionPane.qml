pragma ComponentBehavior: Bound

import QtQuick

// A session: its state, where it works and on what model, Open, which
// attaches to it in kitty, and Kill for a worker, at a second click. The
// master's has its model and effort switch, and while there is no desk a field
// to tell it, since a tell then reaches the master.
BosunPane {
    id: pane

    required property var session
    // While a first click has armed Kill.
    property bool killArmed: false
    readonly property string node: session?.node ?? ""
    readonly property bool isMaster: node === "master"
    readonly property bool attachable: (session?.id ?? "") !== "" && session?.status !== "exited"
    readonly property bool killable: attachable && !["master", "desk"].includes(node) && session?.killed !== true
    readonly property string stateKey: session ? BosunLook.stateOf(session) : "stopped"

    signal killClicked
    signal leave

    function focusIn() {
        if (!tellField.visible)
            return false;
        tellField.focusIn();
        return true;
    }

    title: node
    actions: [
        TextButton {
            visible: pane.attachable
            text: `${BosunLook.open}  Open`
            onClicked: Bosun.attach(pane.session)
        },
        TextButton {
            visible: pane.killable
            text: pane.killArmed ? `${BosunLook.states.killed.glyph}  Kill ${pane.node}?` : `${BosunLook.states.killed.glyph}  Kill`
            hoverFill: Theme.alpha(Theme.red, 0.5)
            lit: pane.killArmed
            onClicked: pane.killClicked()
        }
    ]
    facts: [
        BosunFact {
            glyph: BosunLook.states[pane.stateKey].glyph
            glyphColor: BosunLook.stateColor(pane.stateKey)
            text: pane.session ? BosunLook.stateWords(pane.session) : ""
        },
        BosunFact {
            glyph: BosunLook.folder
            text: BosunLook.tilde(pane.session?.repo || pane.session?.dir)
        },
        BosunFact {
            glyph: BosunLook.branch
            text: pane.session?.base ? `worktree-${pane.node}` : ""
        },
        BosunFact {
            glyph: BosunLook.chip
            text: [pane.session?.model, pane.session?.effort].filter(part => part).join(" ") || (pane.session ? "default model" : "")
        },
        BosunFact {
            glyph: BosunLook.account
            text: pane.session?.parent ? `spawned by ${pane.session.parent}` : ""
        }
    ]

    BosunModelSwitch {
        visible: pane.isMaster && Bosun.connected
        node: pane.node
        session: pane.session
    }

    foot: [
        BosunComposer {
            id: tellField

            width: parent.width
            visible: pane.isMaster && !Bosun.desk && Bosun.connected
            placeholder: "Tell the master"
            onSent: text => Bosun.tell(text)
            onLeave: pane.leave()
        },
        BosunHints {
            model: (tellField.visible ? [
                    {
                        keys: ["Tab"],
                        text: "tell the master"
                    }
                ] : []).concat([
                {
                    keys: ["j", "k"],
                    text: "move"
                },
                {
                    keys: ["n"],
                    text: "new worker"
                }
            ])
        }
    ]
}
