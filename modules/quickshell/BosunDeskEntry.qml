pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

// An entry of the front desk's conversation of a kind BosunDesk adds: the
// user's message on a card, the desk's answer with what it names to open,
// an instruction to the master on a card with what became of it, the
// master's answer on a line that opens, and a decision answered on the
// user's word.
Item {
    id: entry

    required property var item
    // The BosunConversation it sits in.
    required property var conversation
    property bool open: false
    readonly property real cardWidth: Math.min(width, 700)

    signal toggled

    width: parent?.width ?? 0
    height: loader.height

    // Unsized, as a Loader with a width stretches a card to it.
    Loader {
        id: loader

        sourceComponent: {
            switch (entry.item.kind) {
            case "desk-you":
            case "desk-pending":
                return bubble;
            case "desk-text":
                return answer;
            case "desk-instruction":
                return instruction;
            case "desk-master":
                return masterLine;
            }
            return answered;
        }
    }

    Component {
        id: bubble

        BosunCard {
            id: said

            readonly property bool waits: entry.item.kind === "desk-pending"

            width: entry.cardWidth
            caption: waits ? `${BosunLook.queued}  Waits for the desk` : `${BosunLook.account}  You`
            age: BosunLook.ago(entry.item.at, entry.conversation.now)
            mine: true
            outlined: waits
            spacing: 4

            SelectableText {
                width: parent.width
                wrapMode: TextEdit.Wrap
                text: entry.item.text ?? ""
                color: said.waits ? Theme.foregroundMuted : Theme.foregroundStrong
                font.pixelSize: 14
            }
        }
    }

    Component {
        id: answer

        Column {
            width: entry.width
            spacing: 8

            BosunMarkdown {
                markdown: entry.item.text ?? ""
            }

            Flow {
                width: parent.width
                visible: links.count > 0
                spacing: 16

                Repeater {
                    id: links

                    model: BosunDesk.links(entry.item.text ?? "")

                    BosunLink {
                        required property var modelData

                        text: `${modelData.text}  ${BosunLook.chevronRight}`
                        onClicked: entry.conversation.opened(modelData.key, modelData.item)
                    }
                }
            }
        }
    }

    Component {
        id: instruction

        BosunCard {
            id: card

            readonly property var result: entry.item.result ?? null
            readonly property var outcome: BosunDesk.outcome(entry.item.input?.text ?? "", entry.item.at)

            width: entry.cardWidth
            spacing: 8

            Item {
                id: head

                // The chips take the label's line while they fit beside it,
                // and wrap onto lines below it when they don't.
                readonly property bool wraps: headText.implicitWidth + 12 + chips.naturalWidth > width

                width: parent.width
                height: wraps ? headText.implicitHeight + 8 + chips.height : Math.max(headText.implicitHeight, chips.height)

                Caption {
                    id: headText

                    y: head.wraps ? 0 : (head.height - height) / 2
                    text: `${BosunLook.master}  Instruction ${card.outcome?.number || entry.item.number} to the master`
                }

                Flow {
                    id: chips

                    // A Flow's implicitWidth is no single row's, so the row is summed here.
                    readonly property real naturalWidth: {
                        let sum = 0;
                        let shown = 0;
                        for (const child of children) {
                            if (!child.visible || child.width === 0)
                                continue;
                            sum += child.width;
                            shown++;
                        }
                        return sum + Math.max(0, shown - 1) * spacing;
                    }

                    x: head.wraps ? 0 : head.width - width
                    y: head.wraps ? headText.implicitHeight + 8 : (head.height - height) / 2
                    width: head.wraps ? head.width : naturalWidth
                    spacing: 8

                    Repeater {
                        // A ScriptModel adds the chip for an act that
                        // lands, where an array would rebuild them all.
                        model: ScriptModel {
                            objectProp: "seq"
                            values: card.outcome?.acts ?? []
                        }

                        Chip {
                            required property var modelData

                            text: `${BosunLook.check}  ${modelData.kind} ${modelData.node}`
                            tone: modelData.kind === "merged" ? Theme.magenta : Theme.green
                            link: BosunLook.sessionLink(modelData.node)
                        }
                    }

                    Chip {
                        visible: text !== ""
                        text: {
                            if (card.result?.error)
                                return `${BosunLook.close}  not passed on`;
                            if ((card.outcome?.acts ?? []).length > 0)
                                return "";
                            if ((card.outcome?.answers ?? []).length > 0)
                                return `${BosunLook.check}  answered`;
                            return card.result ? "with the master" : "";
                        }
                        tone: card.result?.error ? Theme.red : (card.outcome?.answers ?? []).length > 0 ? Theme.green : Theme.foregroundMuted
                    }

                    Caption {
                        height: 22
                        verticalAlignment: Text.AlignVCenter
                        text: BosunLook.ago(entry.item.at, entry.conversation.now)
                    }
                }
            }

            SelectableText {
                width: parent.width
                wrapMode: TextEdit.Wrap
                text: entry.item.input?.text ?? ""
                color: Theme.foregroundStrong
                font.pixelSize: 14
            }

            SelectableText {
                width: parent.width
                visible: card.result?.error === true
                wrapMode: TextEdit.Wrap
                text: card.result?.text ?? ""
                color: Theme.red
                font.pixelSize: 13
            }
        }
    }

    Component {
        id: masterLine

        Column {
            width: entry.width
            spacing: 6

            BosunLine {
                glyph: BosunLook.master
                label: `The master answered: ${(entry.item.text ?? "").split("\n")[0]}`
                labelColor: Theme.foregroundMuted
                aside: BosunLook.ago(entry.item.at, entry.conversation.now)
                open: entry.open
                onToggled: entry.toggled()
            }

            SelectableText {
                x: 24
                width: parent.width - x
                visible: entry.open
                wrapMode: TextEdit.Wrap
                text: entry.item.text ?? ""
                color: Theme.foregroundMuted
                font.pixelSize: 14
            }
        }
    }

    // What the desk gave and the user's words, which the daemon checked
    // appear in their one message since the desk proposed it.
    Component {
        id: answered

        BosunCard {
            id: given

            readonly property var input: entry.item.input ?? {}
            readonly property var decision: Bosun.answered.find(a => a.decision?.id === input.id)?.decision ?? Bosun.settledEntry(input.id)?.decision ?? null
            readonly property string what: {
                if (input.allow === true)
                    return "Approved";
                if (input.allow === false)
                    return `Denied${input.message ? `: ${input.message}` : ""}`;
                return `Answered: ${input.answer ?? ""}`;
            }

            width: entry.cardWidth
            caption: `${BosunLook.check}  Answered decision ${input.id} on your word`
            captionColor: Theme.green
            age: BosunLook.ago(entry.item.at, entry.conversation.now)

            Row {
                width: parent.width
                visible: given.decision !== null
                spacing: 8

                BarText {
                    text: given.decision ? BosunLook.decisionGlyph(given.decision) : ""
                    color: Theme.foregroundMuted
                    font.pixelSize: 14
                }

                BarText {
                    text: given.decision?.node ?? ""
                    font.pixelSize: 14
                }

                BarText {
                    width: parent.width - x
                    elide: Text.ElideRight
                    text: given.decision ? Bosun.summaryOf(given.decision).split("\n")[0] : ""
                    color: Theme.foregroundMuted
                    font.family: given.decision?.kind === "permission" ? Theme.fontMono : Theme.fontUI
                    font.pixelSize: 13
                }
            }

            SelectableText {
                width: parent.width
                wrapMode: TextEdit.Wrap
                text: given.what
                font.pixelSize: 14
            }

            BosunYouSaid {
                width: parent.width
                words: given.input.words
            }

            BosunLink {
                visible: given.decision !== null
                text: `Open decision ${given.input.id}  ${BosunLook.chevronRight}`
                onClicked: entry.conversation.opened(`decision:${given.input.id}`, given.decision)
            }
        }
    }

    // What became of an instruction, in its tone; a session's opens it.
    component Chip: Rectangle {
        id: chip

        property alias text: chipText.text
        property color tone: Theme.foregroundMuted
        property var link: null

        width: chipText.implicitWidth + 12
        height: chipText.implicitHeight + 4
        radius: 4
        color: Theme.alpha(tone, chipHover.hovered && link ? 0.25 : 0.14)

        BarText {
            id: chipText

            anchors.centerIn: parent
            color: chip.tone
            font.pixelSize: 12
        }

        HoverHandler {
            id: chipHover

            cursorShape: chip.link ? Qt.PointingHandCursor : Qt.ArrowCursor
        }

        TapHandler {
            enabled: chip.link !== null
            onTapped: entry.conversation.opened(chip.link.key, chip.link.item)
        }
    }
}
