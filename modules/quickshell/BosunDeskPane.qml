pragma ComponentBehavior: Bound

import QtQuick

// The front desk: its conversation, as BosunDesk shapes it, and a composer
// that reaches it through `bosun tell`. The desk's model and effort switch
// beside Interrupt and Open in kitty, which attaches to it.
BosunPane {
    id: pane

    readonly property var session: Bosun.desk
    readonly property bool attachable: (session?.id ?? "") !== "" && session?.status !== "exited"

    signal leave
    signal opened(string key, var item)

    function focusIn() {
        if (!composer.visible)
            return false;
        composer.focusIn();
        return true;
    }

    title: "Front desk"
    actions: [
        BosunSegments {
            visible: Bosun.connected && pane.session !== null
            enabled: Bosun.switching !== "desk"
            values: Bosun.models
            current: pane.session?.model ?? ""
            fallback: "default"
            onPicked: value => Bosun.model("desk", value, "")
        },
        BosunSegments {
            visible: Bosun.connected && pane.session !== null
            enabled: Bosun.switching !== "desk"
            values: Bosun.efforts
            current: pane.session?.effort ?? ""
            fallback: "default"
            onPicked: value => Bosun.model("desk", "", value)
        },
        TextButton {
            visible: conversationView.inTurn && pane.attachable && Bosun.connected
            text: `${BosunLook.interrupt}  Interrupt`
            onClicked: Bosun.interrupt("desk")
        },
        TextButton {
            visible: pane.attachable
            text: `${BosunLook.open}  Open in kitty`
            onClicked: Bosun.attach(pane.session)
        }
    ]
    facts: [
        BosunFact {
            glyph: BosunLook.chip
            text: Bosun.switching === "desk" ? "Switching…" : [pane.session?.model, pane.session?.effort].filter(part => part).join(" ") || (pane.session ? "default model" : "")
        },
        BosunFact {
            glyph: BosunLook.eye
            text: "Reads the whole fleet"
        },
        BosunFact {
            glyph: BosunLook.master
            text: "Changes go to the master as instructions"
        }
    ]

    fill: [
        BosunConversation {
            id: conversationView

            anchors.fill: parent
            node: pane.visible ? "desk" : ""
            scrollKey: conversationView.node !== "" ? "session:desk" : ""
            shape: entries => BosunDesk.shape(entries)
            busy: ["busy", "waiting"].includes(pane.session?.status)
            onDecisionOpened: id => pane.opened(`decision:${id}`, null)
            onOpened: (key, item) => pane.opened(key, item)

            Binding {
                target: BosunKept
                property: "deskSeen"
                value: pane.session?.activity?.at ?? ""
                when: pane.visible && pane.session !== null
                restoreMode: Binding.RestoreNone
            }
        }
    ]

    // A tell, unlike a say, queues in the daemon and outlasts a pause, and
    // the desk's `answer` counts it as the user's one message after it
    // proposed an answer from when it was sent.
    foot: [
        BosunComposer {
            id: composer

            width: parent.width
            visible: Bosun.connected
            placeholder: "Ask about the run, or tell the fleet what to do"
            draftKey: "tell"
            onSent: text => Bosun.tell(text)
            onLeave: pane.leave()
        },
        BosunHints {
            model: [
                {
                    keys: ["Ctrl", "Enter"],
                    text: "send"
                },
                {
                    keys: ["Esc"],
                    text: "back to the list"
                },
                {
                    keys: [],
                    text: "A reply that comes while the panel is closed raises a notification"
                }
            ]
        }
    ]
}
