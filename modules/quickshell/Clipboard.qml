pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// cliphist's history, newest first, read again each time the launcher shows
// it. An image shows as a thumbnail, decoded as its row first shows into the
// runtime directory, under its entry's id, which cliphist never reuses.
Singleton {
    id: root

    // { id, text } or { id, image: { format, size, width, height } }.
    property var entries: []
    // By entry id, the decoded image's path, empty while it decodes.
    property var thumbnails: ({})
    readonly property string thumbnailDir: `${Quickshell.env("XDG_RUNTIME_DIR")}/quickshell-clipboard`

    function refresh() {
        lister.running = true;
    }

    // Rows for the panel: the entries holding every word of the query, newest
    // first, an image matching by its format.
    function search(query) {
        const words = Launcher.tokens(query);
        return entries.filter(e => {
            const text = (e.image ? `image ${e.image.format}` : e.text).toLowerCase();
            return words.every(w => text.includes(w));
        }).map(e => ({
                    kind: "clip",
                    entry: e
                }));
    }

    // Out of the bar's unit: wl-copy stays behind to serve an image, which
    // the clipboard keeper takes over only for text.
    function copy(entry) {
        Launcher.run([Programs.sh, "-c", '"$0" decode "$1" | "$2"', Programs.cliphist, entry.id, Programs.wlCopy]);
    }

    function remove(entry) {
        entries = entries.filter(e => e !== entry);
        Quickshell.execDetached([Programs.sh, "-c", 'printf "%s\\n" "$1" | "$0" delete', Programs.cliphist, entry.id]);
    }

    // Once per image entry.
    function decode(entry) {
        if (entry.id in thumbnails)
            return;
        thumbnails = Object.assign({}, thumbnails, {
            [entry.id]: ""
        });
        decoder.createObject(root, {
            entryId: entry.id,
            path: `${thumbnailDir}/${entry.id}.${entry.image.format}`
        });
    }

    Process {
        id: lister

        command: [Programs.cliphist, "list"]
        stdout: StdioCollector {
            onStreamFinished: root.entries = text.split("\n").filter(l => l.includes("\t")).map(line => {
                const tab = line.indexOf("\t");
                const id = line.slice(0, tab);
                const preview = line.slice(tab + 1);
                const image = preview.match(/^\[\[ binary data (.+) (\w+) (\d+)x(\d+) \]\]$/);
                return image ? {
                    id: id,
                    image: {
                        size: image[1],
                        format: image[2],
                        width: Number(image[3]),
                        height: Number(image[4])
                    }
                } : {
                    id: id,
                    text: preview
                };
            })
        }
    }

    Component {
        id: decoder

        Process {
            required property string entryId
            required property string path

            command: [Programs.sh, "-c", 'mkdir -p "${2%/*}" && exec "$0" decode "$1" > "$2"', Programs.cliphist, entryId, path]
            running: true
            onExited: code => {
                if (code === 0)
                    root.thumbnails = Object.assign({}, root.thumbnails, {
                        [entryId]: path
                    });
                destroy();
            }
        }
    }
}
