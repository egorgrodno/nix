pragma ComponentBehavior: Bound

import QtQuick

// The rounded backgrounds of a Markdown text's inline code spans, one a line
// a span covers, at the places `layout` gives: rich text cannot round a
// background. Set under the text, at its origin.
Item {
    id: code

    // A TextEdit holding the text, laid out as it shows.
    required property TextEdit layout
    required property var codes

    // { x, y, width, height } a box. A wrap inside a span falls after a code
    // character, so each line's box ends one cell past the last on it, or at
    // a trailing space. Rich text's `text` reads back as the whole document
    // in HTML, so the layout's other properties stand for its change.
    readonly property var boxes: {
        layout.width;
        layout.length;
        layout.contentHeight;
        layout.font.pixelSize;
        const plain = layout.getText(0, layout.length);
        const cell = cellMetrics.advanceWidth("x");
        const out = [];
        for (const span of MarkdownHtml.spans(plain, codes)) {
            let start = layout.positionToRectangle(span.start);
            let last = start;
            for (let p = span.start + 1; p <= span.end; p++) {
                const at = layout.positionToRectangle(p);
                if (at.y !== start.y) {
                    const right = /\s/.test(plain[p - 1]) ? last.x : last.x + cell;
                    out.push({
                        x: start.x,
                        y: start.y,
                        width: right - start.x,
                        height: start.height
                    });
                    start = at;
                }
                last = at;
            }
            out.push({
                x: start.x,
                y: start.y,
                width: last.x - start.x,
                height: start.height
            });
        }
        return out;
    }

    FontMetrics {
        id: cellMetrics

        font.family: Theme.fontMono
        font.pixelSize: code.layout.font.pixelSize
        font.hintingPreference: code.layout.font.hintingPreference
    }

    Repeater {
        model: code.boxes

        Rectangle {
            required property var modelData

            x: modelData.x
            y: modelData.y + 1
            width: modelData.width
            height: modelData.height - 2
            radius: 4
            color: Theme.tint(0.1)
        }
    }
}
