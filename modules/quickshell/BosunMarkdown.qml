pragma ComponentBehavior: Bound

import QtQuick

// An assistant's text as Markdown, each fenced code block on a tint in
// monospace.
Item {
    id: root

    required property string markdown
    property color color: Theme.foregroundStrong

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

        Repeater {
            model: root.blocks(root.markdown)

            Loader {
                id: block

                required property var modelData

                width: body.width
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
}
