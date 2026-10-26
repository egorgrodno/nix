pragma ComponentBehavior: Bound

import QtQuick

// An edit's hunks, as Claude Code's structuredPatch holds them: each line
// marked by its first character, a removed one on red and an added one on
// green, with a gap between hunks.
Column {
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

    width: parent?.width ?? 0

    Repeater {
        model: diff.rows

        Rectangle {
            id: row

            required property var modelData

            width: diff.width
            height: lineText.implicitHeight + 2
            color: row.modelData.mark === "-" ? Theme.alpha(Theme.red, 0.15) : row.modelData.mark === "+" ? Theme.alpha(Theme.green, 0.15) : "transparent"

            BarText {
                id: markText

                x: 8
                y: 1
                text: row.modelData.mark === "gap" ? "" : row.modelData.mark
                color: Theme.foregroundMuted
                font.family: Theme.fontMono
                font.pixelSize: 13
            }

            BarText {
                id: lineText

                x: 36
                y: 1
                width: parent.width - x - 8
                wrapMode: Text.WrapAnywhere
                text: row.modelData.text
                color: row.modelData.mark === "gap" ? Theme.foregroundMuted : Theme.foregroundStrong
                font.family: Theme.fontMono
                font.pixelSize: 13
            }
        }
    }
}
