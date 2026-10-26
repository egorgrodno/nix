pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// The front desk: its model and effort switch, a field to tell it, which
// `bosun tell` reaches, Open, which attaches to it in kitty, and the decisions
// it answered on the user's word, newest first, each with the words it quoted
// as the yes.
BosunPane {
    id: pane

    readonly property var session: Bosun.desk
    readonly property string stateKey: session ? BosunLook.stateOf(session) : "stopped"

    signal leave

    function focusIn() {
        tellField.focusIn();
        return true;
    }

    title: "Front desk"
    actions: [
        TextButton {
            visible: (pane.session?.id ?? "") !== "" && pane.session?.status !== "exited"
            text: `${BosunLook.open}  Open`
            onClicked: Bosun.attach(pane.session)
        }
    ]
    facts: [
        BosunFact {
            glyph: BosunLook.states[pane.stateKey].glyph
            glyphColor: BosunLook.stateColor(pane.stateKey)
            text: pane.session ? BosunLook.stateWords(pane.session) : ""
        },
        BosunFact {
            glyph: BosunLook.chip
            text: [pane.session?.model, pane.session?.effort].filter(part => part).join(" ") || (pane.session ? "default model" : "")
        }
    ]

    BosunModelSwitch {
        visible: Bosun.connected && pane.session !== null
        node: "desk"
        session: pane.session
    }

    Caption {
        visible: Bosun.answered.length > 0
        text: "Answered on your word"
    }

    Repeater {
        model: ScriptModel {
            values: [...Bosun.answered].reverse()
        }

        delegate: AnsweredRow {}
    }

    foot: [
        BosunComposer {
            id: tellField

            width: parent.width
            placeholder: "Tell the desk"
            onSent: text => Bosun.tell(text)
            onLeave: pane.leave()
        },
        BosunHints {
            model: [
                {
                    keys: ["Enter"],
                    text: "send"
                },
                {
                    keys: ["Esc"],
                    text: "back to the list"
                }
            ]
        }
    ]

    // What the decision was, what the desk gave and the user's words.
    component AnsweredRow: Rectangle {
        id: answer

        required property var modelData
        readonly property var decision: modelData.decision
        readonly property string given: {
            if (decision.kind === "permission")
                return modelData.behavior === "allow" ? "Approved" : `Denied${modelData.text ? `: ${modelData.text}` : ""}`;
            return `Answered: ${modelData.text ?? ""}`;
        }

        width: parent?.width ?? 0
        height: answerBody.implicitHeight + 24
        radius: Theme.radius - 4
        color: Theme.tint(0.04)

        Column {
            id: answerBody

            x: 12
            y: 12
            width: parent.width - 24
            spacing: 4

            Row {
                width: parent.width
                spacing: 8

                BarText {
                    text: BosunLook.decisionGlyph(answer.decision)
                    color: Theme.foregroundMuted
                    font.pixelSize: 14
                }

                BarText {
                    text: answer.decision.node
                    font.pixelSize: 14
                }

                BarText {
                    width: parent.width - x
                    elide: Text.ElideRight
                    text: Bosun.summaryOf(answer.decision).split("\n")[0]
                    color: Theme.foregroundMuted
                    font.family: answer.decision.kind === "permission" ? Theme.fontMono : Theme.fontUI
                    font.pixelSize: 13
                }
            }

            BarText {
                width: parent.width
                wrapMode: Text.Wrap
                font.pixelSize: 14
                text: answer.given
            }

            BarText {
                width: parent.width
                wrapMode: Text.Wrap
                color: Theme.foregroundMuted
                font.pixelSize: 14
                text: `You said: “${answer.modelData.words}”`
            }
        }
    }
}
