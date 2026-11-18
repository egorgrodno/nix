pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The machine's layout as `kb-layout` saves it, and its direction keys.
Singleton {
    readonly property string layout: file.text().trim() === "hallmack" ? "hallmack" : "qwerty"
    readonly property var directions: Host.directions[layout]

    FileView {
        id: file

        path: "/var/lib/keyboard-layout"
        blockAllReads: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
    }
}
