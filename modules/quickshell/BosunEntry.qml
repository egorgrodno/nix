pragma ComponentBehavior: Bound

import QtQuick

// One entry of a session's conversation, as BosunFeed holds it: a prompt, a
// message or a background task's end on a card, the assistant's text, a line
// for a tool call, a compaction or a command that opens at a click, the live
// Thinking or Working line, and a line where a new conversation begins. An
// edit opens on its diff. BosunDeskEntry shows the kinds BosunDesk adds. Any
// kind the panel does not know shows as one bosun cannot show yet.
Item {
    id: entry

    required property var modelData
    // The BosunConversation it sits in, which keeps what is open.
    required property var conversation
    readonly property var item: modelData
    readonly property string kind: BosunLook.entryKinds.includes(item.kind) ? item.kind : (item.kind ?? "").startsWith("desk-") ? "desk" : "raw"
    readonly property bool open: conversation.isOpen(item.id, kind === "tool" && (item.result?.diff ?? []).length > 0)

    function toggle() {
        conversation.toggle(item.id);
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
            case "task":
                return taskCard;
            case "text":
                return textBlock;
            case "tool":
                return toolEntry;
            case "thinking":
            case "working":
            case "compact":
            case "command":
                return foldEntry;
            case "desk":
                return deskEntry;
            case "cleared":
                return clearedLine;
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

    // Claude Code's report of a background task that ended, on a card of
    // one line that opens on where its output went.
    Component {
        id: taskCard

        Rectangle {
            id: task

            readonly property string details: {
                const it = entry.item;
                const lines = [it.outputFile ? `Output  ${it.outputFile}` : "", it.task ? `Task    ${it.task}` : ""].filter(line => line);
                return lines.length > 0 ? lines.join("\n") : it.text ?? "";
            }

            height: taskBody.implicitHeight + 16
            radius: Theme.radius - 4
            color: Theme.tint(0.05)

            Column {
                id: taskBody

                x: 12
                y: 8
                width: parent.width - 24
                spacing: 6

                Line {
                    glyph: ({
                            completed: BosunLook.check,
                            failed: BosunLook.close,
                            stopped: BosunLook.interrupt
                        })[entry.item.status] ?? BosunLook.robot
                    label: entry.item.summary || `Background task ${entry.item.status || "ended"}`
                    opens: task.details !== ""
                    aside: BosunLook.ago(entry.item.at, entry.conversation.now)
                }

                BarText {
                    x: 24
                    width: parent.width - x
                    visible: entry.open && task.details !== ""
                    wrapMode: Text.WrapAnywhere
                    text: task.details
                    color: Theme.foregroundMuted
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                }
            }
        }
    }

    Component {
        id: textBlock

        BosunMarkdown {
            markdown: entry.item.text ?? ""
        }
    }

    // A line that opens on what it holds, a compaction's summary or a
    // command's output, or a live Thinking or Working line BosunConversation
    // adds.
    Component {
        id: foldEntry

        Column {
            readonly property string body: entry.kind === "compact" ? entry.item.summary ?? "" : entry.kind === "command" ? entry.item.output ?? "" : ""

            spacing: 6

            Line {
                glyph: ({
                        thinking: BosunLook.thinking,
                        working: entry.item.started ? BosunLook.running : BosunLook.send,
                        compact: BosunLook.compacted
                    })[entry.kind] ?? BosunLook.command
                label: ({
                        thinking: "Thinking",
                        working: entry.item.started ? "Working" : "Sending",
                        compact: "Compacted"
                    })[entry.kind] ?? [entry.item.name, entry.item.args].filter(part => part).join(" ")
                mono: entry.kind === "command"
                lit: ["thinking", "working"].includes(entry.kind)
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
                mono: BosunLook.activityMono({
                    tool: entry.item.name
                })
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
            }

            Column {
                x: 24
                width: parent.width - x
                visible: entry.open
                spacing: 8

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

    // Where a new conversation begins, the old one's entries above it.
    Component {
        id: clearedLine

        Line {
            glyph: BosunLook.cleared
            label: "Conversation cleared"
            opens: false
            aside: BosunLook.timeOf(entry.item)
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

        width: parent?.width ?? 0
        height: 22

        Row {
            id: lead

            anchors.verticalCenter: parent.verticalCenter
            spacing: 8

            // The chevron's box holds the spinner's place, so the row's width
            // does not change as a call starts or ends. Not hidden by opacity,
            // which the spinner would inherit.
            BarText {
                anchors.verticalCenter: parent.verticalCenter
                text: entry.open ? BosunLook.chevronDown : BosunLook.chevronRight
                color: line.lit || !line.opens ? "transparent" : Theme.foregroundMuted
                font.pixelSize: 14

                BosunSpinner {
                    anchors.centerIn: parent
                    visible: line.lit
                    size: 12
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
