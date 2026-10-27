pragma ComponentBehavior: Bound

import QtQuick

// Todoist's Markdown, wrapped: links and bare URLs, which open in the browser,
// code, bold, italics, list items and headings; anything else as typed.
// Rich text, as StyledText drops a font's face, which code needs. Rich text
// takes a link's colour from CSS, not from `linkColor`.
BarText {
    id: root

    required property string markdown
    // Each inline code span's text, in order.
    readonly property var codes: (markdown.match(/`[^`\n]+`/g) ?? []).map(span => span.slice(1, -1))

    // A span already made a tag hides behind a placeholder from the rules
    // after it. A code span pads with a no-break space a side, in the body's
    // font: Qt collapses any other space with the one beside the span.
    function styled(markdown) {
        const escape = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
        const kept = [];
        const restore = html => html.replace(/\u0001(\d+)\u0001/g, (_, i) => restore(kept[i]));
        const keep = html => `\u0001${kept.push(html) - 1}\u0001`;
        const link = (url, label) => keep(`<a href="${escape(url)}" style="color: ${Theme.blue}">${escape(label)}</a>`);
        const code = text => keep(`&nbsp;<span style="font-family: '${Theme.fontMono}', monospace">${escape(text)}</span>&nbsp;`);
        const bullet = keep(`\u00a0\u00a0<span style="color: ${Theme.foregroundMuted}">•</span>\u00a0`);
        return restore(markdown.split("\n").map(line => {
            const heading = /^#{1,6}\s+/.test(line);
            let html = line.replace(/^#{1,6}\s+/, "").replace(/^\s*[-*+]\s+/, bullet).replace(/`([^`]+)`/g, (_, text) => code(text)).replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (_, label, url) => link(url, label)).replace(/\bhttps?:\/\/[^\s<>]*[^\s<>.,;:!?'")\]]/g, url => link(url, url));
            html = escape(html).replace(/\*\*(.+?)\*\*|__(.+?)__/g, (_, a, b) => `<b>${a ?? b}</b>`).replace(/(^|[^\w*])\*(?!\s)(.+?)\*(?![\w*])/g, "$1<i>$2</i>").replace(/(^|\W)_(?!\s)(.+?)_(?!\w)/g, "$1<i>$2</i>");
            return heading ? `<b>${html}</b>` : html;
        }).join("<br>"));
    }

    text: styled(markdown)
    textFormat: Text.RichText
    wrapMode: Text.Wrap
    onLinkActivated: link => Launcher.run([Programs.xdgOpen, link])

    // The code spans' rounded backgrounds, one a line a span covers. Rich
    // text cannot round a background and Text gives no character's position,
    // so a hidden TextEdit lays out the same text at the same width and the
    // boxes take its positions. A TextEdit would take clicks from what lies
    // under the text, so it only measures.
    Loader {
        z: -1
        active: root.codes.length > 0

        sourceComponent: Item {
            id: code

            // { x, y, width, height } a box. Qt collapses a run of spaces in
            // the code, so the search lets any run stand for one. A wrap
            // inside a span falls after a code character, so each line's box
            // ends one cell past the last on it, or at a trailing space.
            readonly property var boxes: {
                twin.width;
                twin.text;
                twin.font.pixelSize;
                const plain = twin.getText(0, twin.length);
                const cell = cellMetrics.advanceWidth("x");
                const out = [];
                let from = 0;
                for (const text of root.codes) {
                    const find = new RegExp(`\u00a0${text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/\s+/g, "\\s+")}\u00a0`, "g");
                    find.lastIndex = from;
                    const match = find.exec(plain);
                    if (!match)
                        continue;
                    from = find.lastIndex;
                    const end = match.index + match[0].length;
                    let start = twin.positionToRectangle(match.index);
                    let last = start;
                    for (let p = match.index + 1; p <= end; p++) {
                        const at = twin.positionToRectangle(p);
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

            TextEdit {
                id: twin

                width: root.width
                visible: false
                enabled: false
                readOnly: true
                text: root.text
                textFormat: TextEdit.RichText
                wrapMode: TextEdit.Wrap
                font: root.font
                renderType: root.renderType
            }

            FontMetrics {
                id: cellMetrics

                font.family: Theme.fontMono
                font.pixelSize: root.font.pixelSize
                font.hintingPreference: root.font.hintingPreference
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
    }
}
