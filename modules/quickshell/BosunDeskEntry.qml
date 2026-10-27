pragma ComponentBehavior: Bound

import QtQuick

// An entry of the front desk's conversation of a kind BosunDesk adds: the
// user's message on the right, the desk's answer with what it names to open,
// an instruction to the master on a card with what became of it, the
// master's answer on a line that opens, and a decision answered on the
// user's word.
Item {
    id: entry

    required property var item
    // The BosunConversation it sits in.
    required property var conversation
    property bool open: false

    signal toggled

    width: parent?.width ?? 0
    height: loader.height

    Loader {
        id: loader

        width: parent.width
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

        Item {
            id: said

            readonly property bool waits: entry.item.kind === "desk-pending"

            height: bubbleBox.height + (waits ? waitsText.height + 4 : 0)

            Rectangle {
                id: bubbleBox

                anchors.right: parent.right
                width: Math.min(parent.width * 0.75, bubbleText.implicitWidth + 24)
                height: bubbleText.implicitHeight + 20
                radius: Theme.radius - 4
                color: said.waits ? "transparent" : Theme.alpha(Theme.blue, 0.16)
                border.width: said.waits ? 1 : 0
                border.color: Theme.tint(0.16)

                BarText {
                    id: bubbleText

                    x: 12
                    y: 10
                    width: Math.min(implicitWidth, entry.width * 0.75 - 24)
                    wrapMode: Text.Wrap
                    text: entry.item.text ?? ""
                    color: said.waits ? Theme.foregroundMuted : Theme.foregroundStrong
                    font.pixelSize: 14
                }
            }

            Caption {
                id: waitsText

                anchors.right: parent.right
                anchors.top: bubbleBox.bottom
                anchors.topMargin: 4
                visible: said.waits
                text: `${BosunLook.queued}  Waits for the desk`
            }
        }
    }

    Component {
        id: answer

        Column {
            spacing: 8

            BosunMarkdown {
                markdown: entry.item.text ?? ""
                thinking: entry.item.thinking ?? ""
                thinkingOpen: entry.conversation.isOpen(`${entry.item.id}/thinking`, false)
                onThinkingToggled: entry.conversation.toggle(`${entry.item.id}/thinking`)
            }

            Flow {
                width: parent.width
                visible: links.count > 0
                spacing: 16

                Repeater {
                    id: links

                    model: BosunDesk.links(entry.item.text ?? "")

                    Link {
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

        Rectangle {
            id: card

            readonly property var result: entry.item.result ?? null
            readonly property var outcome: BosunDesk.outcome(entry.item.input?.text ?? "", entry.item.at)

            width: Math.min(parent?.width ?? 0, 720)
            height: cardBody.implicitHeight + 24
            radius: Theme.radius - 4
            color: Theme.tint(0.05)

            Column {
                id: cardBody

                x: 12
                y: 12
                width: parent.width - 24
                spacing: 8

                Item {
                    width: parent.width
                    height: Math.max(headText.implicitHeight, chips.height)

                    Caption {
                        id: headText

                        anchors.verticalCenter: parent.verticalCenter
                        text: `${BosunLook.master}  Instruction ${entry.item.number} to the master`
                    }

                    Row {
                        id: chips

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 8

                        Repeater {
                            model: card.outcome?.acts ?? []

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
                            anchors.verticalCenter: parent.verticalCenter
                            text: BosunLook.ago(entry.item.at, entry.conversation.now)
                        }
                    }
                }

                BarText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: entry.item.input?.text ?? ""
                    color: Theme.foregroundStrong
                    font.pixelSize: 14
                }

                BarText {
                    width: parent.width
                    visible: card.result?.error === true
                    wrapMode: Text.Wrap
                    text: card.result?.text ?? ""
                    color: Theme.red
                    font.pixelSize: 13
                }
            }
        }
    }

    Component {
        id: masterLine

        Column {
            spacing: 6

            Item {
                width: parent.width
                height: 22

                BarText {
                    id: masterLead

                    anchors.verticalCenter: parent.verticalCenter
                    text: `${entry.open ? BosunLook.chevronDown : BosunLook.chevronRight}  ${BosunLook.master}`
                    color: Theme.foregroundMuted
                    font.pixelSize: 14
                }

                BarText {
                    anchors.left: masterLead.right
                    anchors.leftMargin: 8
                    anchors.right: masterAgo.left
                    anchors.rightMargin: 16
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: `The master answered: ${(entry.item.text ?? "").split("\n")[0]}`
                    color: Theme.foregroundMuted
                    font.pixelSize: 14
                }

                Caption {
                    id: masterAgo

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: BosunLook.ago(entry.item.at, entry.conversation.now)
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: entry.toggled()
                }
            }

            BarText {
                x: 24
                width: parent.width - x
                visible: entry.open
                wrapMode: Text.Wrap
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

        Rectangle {
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

            width: Math.min(parent?.width ?? 0, 720)
            height: givenBody.implicitHeight + 24
            radius: Theme.radius - 4
            color: Theme.tint(0.05)

            Column {
                id: givenBody

                x: 12
                y: 12
                width: parent.width - 24
                spacing: 6

                Item {
                    width: parent.width
                    height: givenHead.implicitHeight

                    Caption {
                        id: givenHead

                        text: `${BosunLook.check}  Answered decision ${given.input.id} on your word`
                        color: Theme.green
                    }

                    Caption {
                        anchors.right: parent.right
                        text: BosunLook.ago(entry.item.at, entry.conversation.now)
                    }
                }

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

                BarText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: given.what
                    font.pixelSize: 14
                }

                BarText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: `You said: “${given.input.words}”`
                    color: Theme.foregroundMuted
                    font.pixelSize: 14
                }

                Link {
                    visible: given.decision !== null
                    text: `Open decision ${given.input.id}  ${BosunLook.chevronRight}`
                    onClicked: entry.conversation.opened(`decision:${given.input.id}`, given.decision)
                }
            }
        }
    }

    // Blue text that opens what it names.
    component Link: BarText {
        id: link

        signal clicked

        color: linkHover.hovered ? Theme.foregroundStrong : Theme.blue
        font.pixelSize: 14

        HoverHandler {
            id: linkHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: link.clicked()
        }
    }

    // What became of an instruction, in its tone; a session's opens it.
    component Chip: Rectangle {
        id: chip

        property alias text: chipText.text
        property color tone: Theme.foregroundMuted
        property var link: null

        anchors.verticalCenter: parent?.verticalCenter
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
