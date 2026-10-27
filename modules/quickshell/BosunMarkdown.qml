pragma ComponentBehavior: Bound

import QtQuick

// An assistant's text as Markdown, each fenced code block on a tint in
// monospace. With `thinking`, a glyph at its top right opens the thinking
// that came before it, above the text.
Item {
    id: root

    required property string markdown
    // The thinking folded into the text, or "".
    property string thinking
    property bool thinkingOpen: false
    property color color: Theme.foregroundStrong

    signal thinkingToggled

    // The text's prose and code blocks, as { code, text }. A fence that never
    // closes runs to the end, as while a message is cut short.
    function blocks(markdown) {
        const out = [];
        let lines = [];
        let fence = "";
        const flush = code => {
            const text = lines.join("\n");
            if (code || text.trim() !== "")
                out.push({
                    code: code,
                    text: code ? text : text.replace(/^\n+|\n+$/g, "")
                });
            lines = [];
        };
        for (const line of markdown.split("\n")) {
            const match = line.match(/^\s*(`{3,}|~{3,})/);
            if (fence === "") {
                if (match) {
                    flush(false);
                    fence = match[1];
                } else
                    lines.push(line);
            } else if (match && line.trim() === match[1] && match[1][0] === fence[0] && match[1].length >= fence.length) {
                flush(true);
                fence = "";
            } else
                lines.push(line);
        }
        flush(fence !== "");
        return out;
    }

    width: parent?.width ?? 0
    height: body.implicitHeight

    Column {
        id: body

        width: parent.width
        spacing: 8

        BarText {
            x: 24
            width: parent.width - x
            visible: root.thinkingOpen && root.thinking !== ""
            wrapMode: Text.Wrap
            text: root.thinking
            color: Theme.foregroundMuted
            font.pixelSize: 14
        }

        Repeater {
            model: root.blocks(root.markdown)

            Loader {
                id: block

                required property var modelData
                required property int index

                // The glyph sits beside the first block.
                width: body.width - (index === 0 && root.thinking !== "" ? 28 : 0)
                sourceComponent: modelData.code ? codeBlock : prose

                Component {
                    id: prose

                    Markdown {
                        markdown: block.modelData.text
                        color: root.color
                        font.pixelSize: 14
                    }
                }

                Component {
                    id: codeBlock

                    Rectangle {
                        height: codeText.implicitHeight + 2 * codeText.y
                        radius: 4
                        color: Theme.tint(0.06)

                        BarText {
                            id: codeText

                            x: 12
                            y: 10
                            width: parent.width - 2 * x
                            wrapMode: Text.WrapAnywhere
                            text: block.modelData.text
                            color: root.color
                            font.family: Theme.fontMono
                            font.pixelSize: 13
                        }
                    }
                }
            }
        }
    }

    BarText {
        id: thinkingGlyph

        anchors.right: parent.right
        y: root.thinkingOpen ? 0 : 2
        visible: root.thinking !== ""
        text: BosunLook.thinking
        color: thinkingHover.hovered || root.thinkingOpen ? Theme.foregroundStrong : Theme.foregroundMuted
        font.pixelSize: 14

        HoverHandler {
            id: thinkingHover

            cursorShape: Qt.PointingHandCursor
        }

        TapHandler {
            onTapped: root.thinkingToggled()
        }

        Tooltip {
            target: thinkingGlyph
            text: root.thinkingOpen ? "Hide the thinking" : "Show the thinking"
            hovered: thinkingHover.hovered
        }
    }
}
