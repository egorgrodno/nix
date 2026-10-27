pragma ComponentBehavior: Bound

import QtQuick

// The tints of a Markdown pipe table's header and striped rows, one band a
// row: rich text paints a cell's background behind its text only, so a band
// would sit inset from the borders and stop short beside a wrapped cell. Set
// under the text, at its origin; the table's borders draw over the bands.
Item {
    id: bands

    // A TextEdit holding the text, laid out as it shows.
    required property TextEdit layout
    // MarkdownHtml.parse's `tables`: every table in the text, in order.
    required property var tables

    // The cell padding the table's HTML sets, which a band reaches past the text.
    readonly property int padding: 6
    // Qt sets a table 1 px in from the left and ends it 2 px short of the
    // width it is given.
    readonly property int inset: 1
    readonly property int shortfall: 3

    // Where each table's cells start in the layout's text, and where it
    // ends. Qt's plain text marks each cell's start with U+FDD0 and a table's
    // end with U+FDD1, and the bullets are tables too. Rich text's `text`
    // reads back as the whole document in HTML, so the layout's other
    // properties stand for its change.
    readonly property var grids: {
        layout.length;
        const plain = layout.getText(0, layout.length);
        const out = [];
        let open = null;
        for (let p = 0; p < plain.length; p++) {
            if (plain[p] === "﷐") {
                if (!open)
                    out.push(open = {
                        starts: [],
                        end: 0
                    });
                open.starts.push(p + 1);
            } else if (plain[p] === "﷑" && open) {
                open.end = p;
                open = null;
            }
        }
        return out;
    }

    Repeater {
        model: bands.tables

        Item {
            id: table

            required property var modelData
            required property int index

            readonly property var grid: bands.grids[index]
            // The table's width on one line, which it takes unless the
            // layout is narrower.
            readonly property real natural: measure.contentWidth

            // { y, height, color } each tinted row. A row starts where its
            // first line does and ends where the next row starts, or for the
            // last row below the lowest line of its cells.
            readonly property var rows: {
                bands.layout.width;
                bands.layout.length;
                bands.layout.contentHeight;
                bands.layout.font.pixelSize;
                const out = [];
                const cols = modelData.cols;
                const tints = modelData.tints;
                if (!cols || !grid || grid.starts.length < tints.length * cols)
                    return out;
                const top = r => Math.min(...grid.starts.slice(r * cols, (r + 1) * cols).map(p => bands.layout.positionToRectangle(p).y)) - bands.padding - 1;
                const last = tints.length - 1;
                let bottom = 0;
                for (let c = last * cols; c < (last + 1) * cols; c++) {
                    const next = c + 1 < grid.starts.length ? grid.starts[c + 1] - 1 : grid.end;
                    if (next - 1 >= grid.starts[c]) {
                        const at = bands.layout.positionToRectangle(next - 1);
                        bottom = Math.max(bottom, at.y + at.height);
                    }
                }
                bottom += bands.padding;
                for (let r = 0; r <= last; r++) {
                    if (!tints[r])
                        continue;
                    const y = top(r);
                    out.push({
                        y,
                        height: (r < last ? top(r + 1) : bottom) - y,
                        color: tints[r]
                    });
                }
                return out;
            }

            // Not shown: Qt's own single-line layout of the table.
            TextEdit {
                id: measure

                visible: false
                enabled: false
                readOnly: true
                text: table.modelData.html
                textFormat: TextEdit.RichText
                wrapMode: TextEdit.NoWrap
                font: bands.layout.font
                renderType: bands.layout.renderType
            }

            Repeater {
                model: table.rows

                Rectangle {
                    required property var modelData

                    x: bands.inset
                    y: modelData.y
                    width: Math.min(table.natural, bands.layout.width) - bands.shortfall
                    height: modelData.height
                    color: modelData.color
                }
            }
        }
    }
}
