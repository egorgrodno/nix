pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// wlsunset's warm screen at night, on unless the file reads `off`, which skips
// its unit's start; %S in the unit.
Singleton {
    id: root

    readonly property bool on: file.text().trim() === ""

    function toggle() {
        const on = !root.on;
        file.setText(on ? "" : "off");
        Quickshell.execDetached([Programs.systemctl, "--user", on ? "start" : "stop", "wlsunset.service"]);
    }

    FileView {
        id: file

        path: `${Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state"}/night-light`
        blockAllReads: true
        blockWrites: true
        printErrors: false
    }
}
