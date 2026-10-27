pragma ComponentBehavior: Bound

import QtQuick

// Todoist's Markdown, as MarkdownHtml makes it, wrapped; links open in the
// browser. Rich text, as StyledText drops a font's face, which code needs.
// SelectableMarkdown is the same text the mouse selects.
BarText {
    id: root

    required property string markdown
    readonly property var codes: MarkdownHtml.codes(markdown)
    readonly property var parsed: MarkdownHtml.parse(markdown)
    readonly property bool tinted: parsed.tables.some(table => table.tints.some(tint => tint))

    text: parsed.html
    textFormat: Text.RichText
    // A word too long for its line, or for a table's cell, breaks anywhere,
    // so a wide table wraps within the width rather than running past it.
    wrapMode: Text.WrapAtWordBoundaryOrAnywhere
    onLinkActivated: link => Launcher.run([Programs.xdgOpen, link])

    // Text gives no character's position, so a hidden TextEdit lays out the
    // same text at the same width for the code spans' boxes and the table
    // rows' tints. A TextEdit would take clicks from what lies under the
    // text, such as a task card's edit, so it only measures.
    Loader {
        z: -1
        active: root.codes.length > 0 || root.tinted

        sourceComponent: Item {
            TextEdit {
                id: twin

                width: root.width
                visible: false
                enabled: false
                readOnly: true
                text: root.text
                textFormat: TextEdit.RichText
                wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
                font: root.font
                renderType: root.renderType
            }

            Loader {
                active: root.tinted

                sourceComponent: TableBands {
                    layout: twin
                    tables: root.parsed.tables
                }
            }

            Loader {
                active: root.codes.length > 0

                sourceComponent: CodeBoxes {
                    layout: twin
                    codes: root.codes
                }
            }
        }
    }
}
