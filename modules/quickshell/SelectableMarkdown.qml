pragma ComponentBehavior: Bound

import QtQuick

// Markdown the mouse selects: Markdown's text in a SelectableText, which
// places the code spans' boxes and the table rows' tints itself.
SelectableText {
    id: root

    required property string markdown
    readonly property var codes: MarkdownHtml.codes(markdown)
    readonly property var parsed: MarkdownHtml.parse(markdown)

    // Each code span's padding: the no-break space before, and the word
    // joiner and no-break space after.
    function pads() {
        const out = [];
        if (codes.length > 0)
            for (const span of MarkdownHtml.spans(getText(0, length), codes))
                out.push(span.start, span.start + 1, span.end - 2, span.end);
        return out;
    }

    // The selection as it reads: a code span without its padding or word
    // joiners, and a table's cells apart by a tab within a row and by a line
    // between rows. Qt's plain text marks each cell's start with U+FDD0 and a
    // table's end with U+FDD1.
    function copied() {
        const [from, to] = chosenRange();
        const plain = getText(0, length);
        const pads = new Set();
        for (const span of MarkdownHtml.spans(plain, codes))
            pads.add(span.start).add(span.end - 1);
        let out = "";
        let rowY = null;
        for (let p = from; p < to; p++) {
            const c = plain[p];
            if (pads.has(p) || c === "\u2060")
                continue;
            if (c === "\ufdd0") {
                const y = positionToRectangle(p + 1).y;
                out += rowY !== null && y === rowY ? "\t" : out === "" || out.endsWith("\n") ? "" : "\n";
                rowY = y;
            } else if (c === "\ufdd1") {
                out += "\n";
                rowY = null;
            } else
                out += c;
        }
        return out.replace(/[\u2028\u2029]/g, "\n").replace(/\u00a0/g, " ");
    }

    text: parsed.html
    // Without the links, which draw in their own colour whatever the twin's.
    origin: parsed.html.replace(/<a [^>]*>/g, "<span>").replace(/<\/a>/g, "</span>")
    textFormat: TextEdit.RichText
    wrapMode: TextEdit.WrapAtWordBoundaryOrAnywhere
    onLinkActivated: link => Launcher.run([Programs.xdgOpen, link])

    Loader {
        z: -1
        active: root.parsed.tables.some(table => table.tints.some(tint => tint))

        sourceComponent: TableBands {
            layout: root
            tables: root.parsed.tables
        }
    }

    Loader {
        z: -1
        active: root.codes.length > 0

        sourceComponent: CodeBoxes {
            layout: root
            codes: root.codes
        }
    }
}
