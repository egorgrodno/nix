import QtQuick

// Todoist's Markdown, wrapped: links and bare URLs, which open in the browser,
// code, bold, italics, list items and headings; anything else as typed.
// Rich text, as StyledText drops a font's face and a background, which code
// needs. Rich text takes a link's colour from CSS, not from `linkColor`.
BarText {
    required property string markdown

    // A span already made a tag hides behind a placeholder from the rules
    // after it.
    function styled(markdown) {
        const escape = s => s.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;").replace(/"/g, "&quot;");
        const kept = [];
        const keep = html => `\u0001${kept.push(html) - 1}\u0001`;
        const link = (url, label) => keep(`<a href="${escape(url)}" style="color: ${Theme.blue}">${escape(label)}</a>`);
        const code = text => keep(`<span style="font-family: '${Theme.fontMono}', monospace; background-color: ${Theme.tint(0.1)}">\u2009${escape(text)}\u2009</span>`);
        const bullet = keep(`\u00a0\u00a0<span style="color: ${Theme.foregroundMuted}">•</span>\u00a0`);
        return markdown.split("\n").map(line => {
            const heading = /^#{1,6}\s+/.test(line);
            let html = line.replace(/^#{1,6}\s+/, "").replace(/^\s*[-*+]\s+/, bullet).replace(/`([^`]+)`/g, (_, text) => code(text)).replace(/\[([^\]]+)\]\(([^)\s]+)\)/g, (_, label, url) => link(url, label)).replace(/\bhttps?:\/\/[^\s<>]*[^\s<>.,;:!?'")\]]/g, url => link(url, url));
            html = escape(html).replace(/\*\*(.+?)\*\*|__(.+?)__/g, (_, a, b) => `<b>${a ?? b}</b>`).replace(/(^|[^\w*])\*(?!\s)(.+?)\*(?![\w*])/g, "$1<i>$2</i>").replace(/(^|\W)_(?!\s)(.+?)_(?!\w)/g, "$1<i>$2</i>");
            return heading ? `<b>${html}</b>` : html;
        }).join("<br>").replace(/\u0001(\d+)\u0001/g, (_, i) => kept[i]);
    }

    text: styled(markdown)
    textFormat: Text.RichText
    wrapMode: Text.Wrap
    onLinkActivated: link => Launcher.run([Programs.xdgOpen, link])
}
