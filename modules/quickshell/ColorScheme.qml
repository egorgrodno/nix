pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Light or dark, as `color-scheme` saves it. The palette follows the file,
// wherever the change came from.
Singleton {
    id: root

    readonly property bool light: file.text().trim() === "light"

    function set(scheme) {
        Quickshell.execDetached([Programs.colorScheme, scheme]);
    }

    FileView {
        id: file

        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/color-scheme`
        blockAllReads: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }

    IpcHandler {
        target: "theme"

        function toggle(): void {
            root.set("toggle");
        }

        function light(): void {
            root.set("light");
        }

        function dark(): void {
            root.set("dark");
        }
    }
}
