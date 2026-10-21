pragma Singleton

import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The wallpapers in ~/Pictures/Wallpapers, and the one awww shows on every
// output. One shows at once, through awww's circle growing out of a point on
// the screen, one `img` at a time with the latest asked for next. awww restores
// each output's image at login from a cache that an awww update empties, so
// the one kept is saved here too, and wins: at start, and whenever the
// folder's listing changes while the panel is closed, an output awww reports
// with another image gets it, as one left previewing by a restart does. With
// none kept, an output without an image gets the first wallpaper, as on a
// fresh install once one arrives. A second after a layout applies or a monitor
// connects, every output gets its image again: awww redraws a resized output
// from its cache, sized for a scale the output passes through on the way, and
// drops what does not fit.
Singleton {
    id: root

    readonly property string folder: `${Quickshell.env("HOME")}/Pictures/Wallpapers`
    // Unset until `test -d` says so: given a missing folder, the model lists
    // the bar's working directory instead.
    property bool present: false
    readonly property int count: present ? listing.count : 0
    readonly property FolderListModel files: listing
    // On the focused output, as awww reported it or as last sent.
    property string shown: ""
    property string saved: ""
    // While the panel is open, whose previews the listing leaves alone.
    property bool picking: false
    // { path, at } for the `img` after the one running.
    property var next: null
    // Every output's, so no frame is skipped.
    readonly property int fps: Math.round(Math.max(60, ...Monitors.outputs.filter(o => !o.disabled).map(o => o.refreshRate)))
    // From a layout or a new monitor until awww has the image sent after it.
    readonly property bool settling: settle.running || redrawer.running

    signal toggleRequested

    function path(index) {
        return listing.get(index, "filePath");
    }

    function indexOf(file) {
        for (let i = 0; i < count; i++)
            if (path(i) === file)
                return i;
        return -1;
    }

    // From a point on the screen, as fractions with y from the bottom as awww
    // takes it, the circle growing out of it, or with `shrink` closing into it
    // over the image it replaces; at once without one.
    function show(file, at, shrink) {
        shown = file;
        next = {
            path: file,
            at: at ?? null,
            shrink: shrink ?? false
        };
        if (!setter.running)
            send();
    }

    function keep(file) {
        saved = file;
        storage.setText(JSON.stringify({
            path: file
        }));
    }

    // Looks again for a folder made or removed since.
    function rescan() {
        checker.running = true;
    }

    function openFolder() {
        opener.running = true;
    }

    function send() {
        const job = next;
        next = null;
        const at = job.at;
        const transition = at ? ["--transition-type", job.shrink ? "outer" : "grow", "--transition-pos", `${at.x.toFixed(3)},${at.y.toFixed(3)}`, "--transition-duration", "0.8", "--transition-fps", String(fps),
            // Hyprland's `snappy`.
            "--transition-bezier", ".2,1,.2,1"] : ["--transition-type", "none"];
        setter.command = [Programs.awww, "img", ...transition, job.path];
        setter.running = true;
    }

    // The kept one while it is there, else the first.
    function fallback() {
        return indexOf(saved) >= 0 ? saved : count > 0 ? path(0) : "";
    }

    function fill(outputs) {
        if (picking)
            return;
        const file = fallback();
        const kept = saved !== "" && file === saved;
        const wrong = outputs.filter(o => kept ? o.displaying.image !== saved : !o.displaying.image).map(o => o.name);
        const focused = outputs.find(o => o.name === Hyprland.focusedMonitor?.name) ?? outputs[0];
        shown = wrong.includes(focused?.name) ? file : focused?.displaying.image ?? shown;
        if (wrong.length > 0 && file !== "")
            Quickshell.execDetached([Programs.awww, "img", "--outputs", wrong.join(","), "--transition-type", "none", file]);
    }

    function redraw() {
        const file = shown || fallback();
        if (file === "")
            return;
        shown = file;
        redrawer.command = [Programs.awww, "img", "--transition-type", "none", file];
        redrawer.running = true;
    }

    FolderListModel {
        id: listing

        folder: root.present ? `file://${root.folder}` : ""
        nameFilters: ["*.png", "*.jpg", "*.jpeg"]
        caseSensitive: false
        showDirs: false
        // Ready again after each change to the folder.
        onStatusChanged: if (status === FolderListModel.Ready)
            query.running = true
    }

    Process {
        id: checker

        command: [Programs.sh, "-c", 'test -d "$0"', root.folder]
        onExited: code => root.present = code === 0
    }

    // Made first, so the model, which ignores a folder until it exists, then
    // watches it.
    Process {
        id: opener

        command: [Programs.sh, "-c", 'mkdir -p "$0"', root.folder]
        onExited: code => {
            if (code === 0)
                root.present = true;
            Launcher.run([Programs.pcmanfm, root.folder]);
        }
    }

    Process {
        id: setter

        onExited: if (root.next)
            root.send()
    }

    Process {
        id: redrawer
    }

    Process {
        id: query

        command: [Programs.awww, "query", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.fill(JSON.parse(text)[""] ?? []);
                } catch (e) {}
            }
        }
        // The daemon can start after the bar, as at login.
        onExited: code => {
            if (code === 0)
                retry.left = 10;
            else if (retry.left-- > 0)
                retry.restart();
        }
    }

    Timer {
        id: retry

        property int left: 10

        interval: 1000
        onTriggered: query.running = true
    }

    // Once the outputs have their surfaces and scales.
    Timer {
        id: settle

        interval: 1000
        onTriggered: root.redraw()
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "monitoradded")
                settle.restart();
        }
    }

    Connections {
        target: Monitors

        function onApplied() {
            settle.restart();
        }
    }

    FileView {
        id: storage

        path: Quickshell.statePath("wallpaper.json")
        blockAllReads: true
        printErrors: false
    }

    Component.onCompleted: {
        try {
            saved = JSON.parse(storage.text()).path ?? "";
        } catch (e) {}
        checker.running = true;
    }

    IpcHandler {
        target: "wallpapers"

        function toggle(): void {
            root.toggleRequested();
        }
    }
}
