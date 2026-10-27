pragma Singleton

import QtQuick
import Quickshell

// Markdown as the rich text Markdown and SelectableMarkdown show: links and
// bare URLs, code, bold, italics, list items, headings and pipe tables;
// anything else as typed. Rich text takes a link's colour from CSS, not from
// `linkColor`.
Singleton {
    // Each inline code span's text, in order.
    function codes(markdown) {
        return (markdown.match(/`[^`\n]+`/g) ?? []).map(span => span.slice(1, -1));
    }

    // Where each of `codes` sits in a layout's plain text, as { start, end },
    // its padding included. Qt collapses a run of spaces in the code, so the
    // search lets any run stand for one.
    function spans(plain, codes) {
        const out = [];
        let from = 0;
        for (const text of codes) {
            const find = new RegExp(`\u00a0${text.replace(/[.*+?^${}()|[\]\\]/g, "\\$&").replace(/\s+/g, "\\s+")}\u00a0`, "g");
            find.lastIndex = from;
            const match = find.exec(plain);
            if (!match)
                continue;
            from = find.lastIndex;
            out.push({
                start: match.index,
                end: find.lastIndex
            });
        }
        return out;
    }

    // A span already made a tag hides behind a placeholder from the rules
    // after it. A code span pads with a no-break space a side, in the body's
    // font: Qt collapses any other space with the one beside the span.
    function html(markdown) {
        const escape = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
        const kept = [];
        const restore = html => html.replace(/\u0001(\d+)\u0001/g, (_, i) => restore(kept[i]));
        const keep = html => `\u0001${kept.push(html) - 1}\u0001`;
        const link = (url, label) => keep(`<a href="${escape(url)}" style="color: ${Theme.blue}">${escape(label)}</a>`);
        const code = text => keep(`&nbsp;<span style="font-family: '${Theme.fontMono}', monospace">${escape(text)}</span>&nbsp;`);
        const inline = text => {
            const html = text.replace(/`([^`]+)`/g, (_, text) => code(text)).replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (_, label, url) => link(url, label)).replace(/\bhttps?:\/\/[^\s<>]*[^\s<>.,;:!?'")\]]/g, url => link(url, url));
            return escape(html).replace(/\*\*(.+?)\*\*|__(.+?)__/g, (_, a, b) => `<b>${a ?? b}</b>`).replace(/(^|[^\w*])\*(?!\s)(.+?)\*(?![\w*])/g, "$1<i>$2</i>").replace(/(^|\W)_(?!\s)(.+?)_(?!\w)/g, "$1<i>$2</i>");
        };
        const lines = markdown.split("\n");
        // Each line's HTML, or a table's, which is a block of its own and
        // takes no break around it. Qt folds the first break after a table
        // into its end, so an empty line there takes one of its own.
        const out = [];
        // The open list levels, outermost first: indent, where the marker
        // starts and its cell's width.
        const levels = [];
        for (let i = 0; i < lines.length; i++) {
            const head = tableCells(lines[i]);
            const rule = i + 1 < lines.length ? tableCells(lines[i + 1]) : null;
            if (head && rule?.length === head.length && rule.every(cell => /^:?-+:?$/.test(cell))) {
                const rows = [head];
                for (i += 2; i < lines.length && lines[i].includes("|"); i++)
                    rows.push(tableCells(lines[i]));
                i--;
                out.push({
                    block: true,
                    html: table(rows, rule, inline)
                });
                continue;
            }
            const heading = /^#{1,6}\s+/.test(lines[i]);
            const item = /^(\s*)([-*+]|\d+[.)])\s+(.*)$/.exec(lines[i]);
            if (item) {
                // Each deeper indent opens a level; a shallower one closes
                // the levels it passes. A sub-item starts under its parent's text.
                const indent = item[1].replace(/\t/g, "    ").length;
                while (levels.length > 0 && indent < levels[levels.length - 1].indent)
                    levels.pop();
                if (levels.length === 0 || indent > levels[levels.length - 1].indent)
                    levels.push({
                        indent,
                        left: levels.length > 0 ? levels[levels.length - 1].left + levels[levels.length - 1].width : 0,
                        width: 0
                    });
                const level = levels[levels.length - 1];
                const ordered = /^\d/.test(item[2]);
                level.width = ordered ? 40 : 28;
                const marker = ordered ? item[2] : ["•", "◦", "▪"][(levels.length - 1) % 3];
                out.push({
                    block: true,
                    html: bulletRow(inline(item[3]), marker, level.left, level.width)
                });
                continue;
            }
            levels.length = 0;
            const html = inline(lines[i].replace(/^#{1,6}\s+/, ""));
            out.push({
                block: false,
                html: heading ? `<b>${html}</b>` : html
            });
        }
        return restore(out.map((part, i) => {
            if (i === 0 || part.block)
                return part.html;
            return out[i - 1].block ? part.html || "<br>" : `<br>${part.html}`;
        }).join(""));
    }

    // A bullet and its text as the two cells of a borderless row, so a line
    // that wraps hangs under the text. The marker cell's right padding is the
    // gap, and a blank cell of `left` px before it nests the item.
    function bulletRow(html, marker, left, width) {
        const pad = left > 0 ? `<td width="${left}"></td>` : "";
        return `<table width="100%" cellspacing="0" cellpadding="0"><tr>${pad}<td width="${width}" valign="top" style="padding-left: 6px; padding-right: 12px; color: ${Theme.foregroundMuted}">${marker}</td><td valign="top">${html}</td></tr></table>`;
    }

    // A table row's cells, trimmed, or null for a line without a pipe. A
    // pipe escaped with a backslash stays in its cell.
    function tableCells(line) {
        if (!line.includes("|"))
            return null;
        const cells = line.trim().replace(/\\\|/g, "\u0002").replace(/^\|/, "").replace(/\|$/, "").split("|");
        return cells.map(cell => cell.trim().replace(/\u0002/g, "|"));
    }

    // GitHub's pipe table: the header row on a tint, each column aligned as
    // its rule's colons say, every other row tinted faintly, and a hairline
    // between the cells. A row short of cells is filled out, and cells past
    // the header's count are dropped.
    //
    // Qt paints a cell's background-color or bgcolor behind its text only, so
    // a tint on the cell or its row sits inset from the borders. A table's own
    // background fills the whole table, so each cell holds a one-cell table at
    // full width, which carries the tint and the padding. The outer table
    // collapses its 1 px border and its cells have no padding of their own.
    // The border is opaque, as a translucent one is drawn twice where two
    // cells meet. A cell that wraps makes its row taller than the other
    // cells' tables, which Qt cannot stretch, so their tint stops short.
    function table(rows, rule, inline) {
        const aligns = rule.map(cell => cell.endsWith(":") ? (cell.startsWith(":") ? "center" : "right") : "left");
        const row = (cells, i) => {
            const tag = i === 0 ? "th" : "td";
            const tint = i === 0 ? Theme.tint(0.08) : i % 2 === 0 ? Theme.tint(0.03) : null;
            const fill = tint ? ` style="background-color: ${tint}"` : "";
            return `<tr>${aligns.map((align, c) => `<td><table width="100%" cellspacing="0" cellpadding="6"${fill}><tr><${tag} align="${align}">${inline(cells[c] ?? "")}</${tag}></tr></table></td>`).join("")}</tr>`;
        };
        return `<table cellspacing="0" cellpadding="0" border="1" style="border-collapse: collapse; border-style: solid; border-color: ${Theme.foregroundFaint}">${rows.map(row).join("")}</table>`;
    }
}
