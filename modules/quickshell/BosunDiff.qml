pragma ComponentBehavior: Bound

import QtQuick

// An edit's hunks, as Claude Code's structuredPatch holds them: each line
// marked by its first character, a removed one on red and an added one on
// green, with a gap between hunks. The lines are one selectable text, so a
// drag spans them and a copy holds them joined by newlines, without the
// marks, which sit in a column of their own. The tints are bands behind the
// text, one a line, placed by where each line starts.
Item {
    id: diff

    property var hunks: []
    // Past this many lines the rest are counted, not drawn.
    property int cap: 400
    readonly property var rows: {
        const rows = [];
        let total = 0;
        (hunks ?? []).forEach((hunk, i) => {
            if (i > 0)
                rows.push({
                    mark: "gap",
                    text: "⋯"
                });
            for (const line of hunk.lines ?? []) {
                total++;
                if (total <= cap)
                    rows.push({
                        mark: line.charAt(0),
                        text: line.slice(1)
                    });
            }
        });
        if (total > cap)
            rows.push({
                mark: "gap",
                text: `${total - cap} more lines`
            });
        return rows;
    }
    // Each line as a block of its own, in its colour. An empty line holds a
    // no-break space, which a block needs to keep its height.
    readonly property string html: rows.map(r => {
        const color = r.mark === "gap" ? Theme.foregroundMuted : Theme.foregroundStrong;
        const text = r.text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
        return `<div style="color:${color}; white-space:pre-wrap">${text === "" ? "&nbsp;" : text}</div>`;
    }).join("")
    // Where each line starts in the text: its length and the break after it.
    readonly property var starts: {
        const out = [];
        let at = 0;
        for (const r of rows) {
            out.push(at);
            at += Math.max(1, r.text.length) + 1;
        }
        return out;
    }
    // The y of each line within the text, and the text's end after them.
    // `starts` follows the rows before the text does, so a start can lie past
    // the text's end, which Qt warns of, until `laidOut` brings the text.
    readonly property var tops: {
        lines.width;
        lines.contentHeight;
        lines.laidOut;
        const end = lines.length;
        const ys = starts.map(p => p <= end ? lines.positionToRectangle(p).y : 0);
        ys.push(lines.contentHeight);
        return ys;
    }

    width: parent?.width ?? 0
    height: lines.contentHeight + 2

    // A band runs from its line's top to the next line's, so the bands meet,
    // and the first and last reach the block's edges.
    Repeater {
        model: diff.rows

        Rectangle {
            required property var modelData
            required property int index

            y: index === 0 ? 0 : (diff.tops[index] ?? 0) + lines.y
            width: diff.width
            height: (index + 1 < diff.rows.length ? (diff.tops[index + 1] ?? 0) + lines.y : diff.height) - y
            color: modelData.mark === "-" ? Theme.alpha(Theme.red, 0.15) : modelData.mark === "+" ? Theme.alpha(Theme.green, 0.15) : "transparent"
        }
    }

    Repeater {
        model: diff.rows

        BarText {
            required property var modelData
            required property int index

            x: 8
            y: (diff.tops[index] ?? 0) + lines.y
            text: modelData.mark === "gap" ? "" : modelData.mark
            color: Theme.foregroundMuted
            font.family: Theme.fontMono
            font.pixelSize: 13
        }
    }

    SelectableText {
        id: lines

        // Counts the text's changes, which rich text's `text` cannot stand
        // for: it reads back as the whole document in HTML.
        property int laidOut: 0

        // An empty line's no-break space copies as nothing.
        function copied() {
            return selectedText.replace(/[\u2028\u2029]/g, "\n").replace(/^\u00a0$/gm, "").replace(/\u00a0/g, " ");
        }

        x: 36
        y: 1
        width: diff.width - x - 8
        wrapMode: TextEdit.WrapAnywhere
        textFormat: TextEdit.RichText
        text: diff.html
        font.family: Theme.fontMono
        font.pixelSize: 13
        onTextChanged: laidOut++
    }
}
