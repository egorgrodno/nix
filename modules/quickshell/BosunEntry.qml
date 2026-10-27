pragma ComponentBehavior: Bound

import QtQuick

// One entry of a session's conversation, as BosunFeed holds it: a prompt or
// a message on a card, the assistant's text, and a line for a tool call,
// thinking, a compaction or a command that opens at a click. An edit opens on
// its diff. BosunDeskEntry shows the kinds BosunDesk adds. Any kind the panel
// does not know shows as one bosun cannot show yet.
Item {
    id: entry

    required property var modelData
    // The BosunConversation it sits in, which keeps what is open.
    required property var conversation
    readonly property var item: modelData
    readonly property string kind: BosunLook.entryKinds.includes(item.kind) ? item.kind : (item.kind ?? "").startsWith("desk-") ? "desk" : "raw"
    readonly property bool open: conversation.isOpen(item.id, kind === "tool" && (item.result?.diff ?? []).length > 0)
    // Whether the thinking BosunConversation folded into a text shows.
    readonly property bool thinkingOpen: conversation.isOpen(`${item.id}/thinking`, false)

    function toggle() {
        conversation.toggle(item.id);
    }

    function toggleThinking() {
        conversation.toggle(`${item.id}/thinking`);
    }

    width: ListView.view?.width ?? 0
    height: loader.height

    Loader {
        id: loader

        width: parent.width
        sourceComponent: {
            switch (entry.kind) {
            case "prompt":
            case "queued":
                return promptCard;
            case "text":
                return textBlock;
            case "tool":
                return toolEntry;
            case "thinking":
            case "compact":
            case "command":
                return foldEntry;
            case "desk":
                return deskEntry;
            }
            return rawEntry;
        }
    }

    Component {
        id: promptCard

        Rectangle {
            id: card

            readonly property bool queued: entry.kind === "queued"

            height: cardBody.implicitHeight + 24
            radius: Theme.radius - 4
            color: queued ? "transparent" : Theme.tint(0.05)
            border.width: queued ? 1 : 0
            border.color: Theme.tint(0.12)

            Column {
                id: cardBody

                x: 12
                y: 12
                width: parent.width - 24
                spacing: 4

                Item {
                    width: parent.width
                    height: whoText.implicitHeight

                    Caption {
                        id: whoText

                        text: card.queued ? `${BosunLook.queued}  Queued for the turn` : `${BosunLook.promptGlyph(entry.item, entry.conversation.parentNode)}  ${BosunLook.promptTitle(entry.item, entry.conversation.parentNode)}`
                    }

                    Caption {
                        anchors.right: parent.right
                        text: BosunLook.ago(entry.item.at, entry.conversation.now)
                    }
                }

                BarText {
                    width: parent.width
                    wrapMode: Text.Wrap
                    text: entry.item.text ?? ""
                    color: card.queued ? Theme.foregroundMuted : Theme.foregroundStrong
                    font.pixelSize: 14
                }
            }
        }
    }

    Component {
        id: textBlock

        BosunMarkdown {
            markdown: entry.item.text ?? ""
            thinking: entry.item.thinking ?? ""
            thinkingOpen: entry.thinkingOpen
            onThinkingToggled: entry.toggleThinking()
        }
    }

    // A line that opens on what it holds: thinking, a compaction's summary or
    // a command's output.
    Component {
        id: foldEntry

        Column {
            readonly property string body: entry.kind === "thinking" ? entry.item.text ?? "" : entry.kind === "compact" ? entry.item.summary ?? "" : entry.item.output ?? ""

            spacing: 6

            Line {
                glyph: entry.kind === "thinking" ? BosunLook.thinking : entry.kind === "compact" ? BosunLook.compacted : BosunLook.command
                label: entry.kind === "thinking" ? "Thinking" : entry.kind === "compact" ? "Compacted" : [entry.item.name, entry.item.args].filter(part => part).join(" ")
                mono: entry.kind === "command"
                opens: parent.body !== ""
            }

            BarText {
                x: 24
                width: parent.width - x
                visible: entry.open && parent.body !== ""
                wrapMode: Text.Wrap
                text: parent.body
                color: Theme.foregroundMuted
                font.family: entry.kind === "command" ? Theme.fontMono : Theme.fontUI
                font.pixelSize: entry.kind === "command" ? 13 : 14
            }
        }
    }

    Component {
        id: toolEntry

        Column {
            id: tool

            readonly property var result: entry.item.result ?? null
            readonly property var counts: BosunLook.diffCounts(result?.diff)
            readonly property bool hasDiff: (result?.diff ?? []).length > 0
            readonly property var lines: (result?.text ?? "").split("\n")
            // A call without a result runs only while the session is in its
            // turn; a stop leaves it without one.
            readonly property bool runs: result === null && entry.conversation.inTurn

            spacing: 6

            Line {
                glyph: BosunLook.activityGlyph({
                    tool: entry.item.name
                })
                label: BosunLook.toolArg(entry.item) || entry.item.name
                mono: true
                lit: tool.runs
                aside: {
                    if (tool.runs)
                        return `running for ${BosunLook.span(entry.conversation.now - new Date(entry.item.at).getTime())}`;
                    if (tool.result === null)
                        return "no result";
                    if (tool.result.interrupted)
                        return "interrupted";
                    if (tool.result.error)
                        return `${BosunLook.close}  ${tool.lines[0]}`;
                    if (tool.hasDiff)
                        return "";
                    return tool.lines.length > 1 ? `${tool.lines.length} lines` : tool.lines[0];
                }
                asideColor: tool.runs ? Theme.blue : tool.result?.error ? Theme.red : Theme.foregroundMuted
                added: tool.hasDiff ? tool.counts.added : -1
                removed: tool.hasDiff ? tool.counts.removed : -1
                thought: (entry.item.thinking ?? "") !== ""
            }

            Column {
                x: 24
                width: parent.width - x
                visible: entry.open
                spacing: 8

                // The thinking BosunConversation folded into the call.
                BarText {
                    width: parent.width
                    visible: (entry.item.thinking ?? "") !== ""
                    wrapMode: Text.Wrap
                    text: entry.item.thinking ?? ""
                    color: Theme.foregroundMuted
                    font.pixelSize: 14
                }

                BosunDiff {
                    visible: tool.hasDiff
                    hunks: tool.result?.diff ?? []
                }

                // The call's input, but for the edit its diff shows.
                Repeater {
                    model: entry.open && !tool.hasDiff ? Bosun.callOf({
                        tool: entry.item.name,
                        input: entry.item.input
                    }) : []

                    delegate: BosunCallBlock {}
                }

                BosunCallBlock {
                    visible: entry.open && tool.result !== null && !tool.hasDiff && (tool.result.text ?? "") !== ""
                    modelData: ({
                            kind: tool.result?.error ? "removed" : "code",
                            label: tool.result?.error ? "Error" : "Result",
                            text: tool.lines.length > 200 ? `${tool.lines.slice(0, 200).join("\n")}\n… ${tool.lines.length - 200} more lines` : tool.result?.text ?? ""
                        })
                }
            }
        }
    }

    Component {
        id: deskEntry

        BosunDeskEntry {
            item: entry.item
            conversation: entry.conversation
            open: entry.open
            onToggled: entry.toggle()
        }
    }

    Component {
        id: rawEntry

        BosunRawEntry {
            type: entry.item.recordType ?? entry.item.kind ?? ""
            json: entry.item.raw ?? entry.item
            open: entry.open
            onToggled: entry.toggle()
        }
    }

    // A line that opens at a click: a chevron, a glyph, what it is, and on
    // the right a word on how it went.
    component Line: Item {
        id: line

        property string glyph
        property string label
        property bool mono: false
        property bool opens: true
        property bool lit: false
        property string aside
        property color asideColor: Theme.foregroundMuted
        // A diff's counts, or -1 for none.
        property int added: -1
        property int removed: -1
        // Whether opening it shows thinking too.
        property bool thought: false

        width: parent?.width ?? 0
        height: 22

        Row {
            id: lead

            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            BarText {
                anchors.verticalCenter: parent.verticalCenter
                text: line.lit ? BosunLook.running : entry.open ? BosunLook.chevronDown : BosunLook.chevronRight
                color: line.lit ? Theme.blue : Theme.foregroundMuted
                opacity: line.opens || line.lit ? 1 : 0
                font.pixelSize: 14

                RotationAnimation on rotation {
                    running: line.lit
                    from: 0
                    to: 360
                    duration: 1000
                    loops: Animation.Infinite
                }
            }

            BarText {
                anchors.verticalCenter: parent.verticalCenter
                text: line.glyph
                color: line.lit ? Theme.blue : Theme.foregroundMuted
                font.pixelSize: 14
            }
        }

        BarText {
            anchors.left: lead.right
            anchors.leftMargin: 8
            anchors.right: tail.left
            anchors.rightMargin: 16
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: line.label
            color: line.lit ? Theme.blue : Theme.foregroundMain
            font.family: line.mono ? Theme.fontMono : Theme.fontUI
            font.pixelSize: line.mono ? 13 : 14
        }

        Row {
            id: tail

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            BarText {
                visible: line.thought
                text: BosunLook.thinking
                color: Theme.foregroundMuted
                font.pixelSize: 13
            }

            BarText {
                visible: line.added >= 0
                text: `+${line.added}`
                color: Theme.green
                font.pixelSize: 13
            }

            BarText {
                visible: line.removed >= 0
                text: `−${line.removed}`
                color: Theme.red
                font.pixelSize: 13
            }

            BarText {
                width: Math.min(implicitWidth, 320)
                visible: line.aside !== ""
                elide: Text.ElideRight
                text: line.aside
                color: line.asideColor
                font.pixelSize: 13
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: line.opens
            cursorShape: Qt.PointingHandCursor
            onClicked: entry.toggle()
        }
    }
}
