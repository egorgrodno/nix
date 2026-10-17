pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The backlight brightnessctl picks by default, as the brightness keys do.
// Writes go through brightnessctl, since the sysfs file is root's.
Singleton {
    id: root

    // Empty where there is no backlight.
    property string device
    property int max
    // Raw, as last read or set.
    property int level
    readonly property int percent: max > 0 ? Math.round(level * 100 / max) : 0
    // A write waiting for the one in flight; a newer value replaces it.
    property int pending: -1

    function read() {
        // A read during a write would undo the level just set.
        if (device === "" || writer.running || pending >= 0)
            return;
        current.reload();
        level = parseInt(current.text());
    }

    function set(raw) {
        if (device === "")
            return;
        level = Math.max(0, Math.min(max, raw));
        pending = level;
        if (!writer.running)
            flush();
    }

    function setPercent(percent) {
        set(Math.round(percent * max / 100));
    }

    function flush() {
        if (pending < 0)
            return;
        writer.command = [Programs.brightnessctl, "-q", "-d", device, "set", String(pending)];
        pending = -1;
        writer.running = true;
    }

    // device,class,current,percent,max
    Process {
        running: true
        command: [Programs.brightnessctl, "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(",");
                if (fields.length !== 5)
                    return;
                root.max = parseInt(fields[4]);
                root.level = parseInt(fields[2]);
                root.device = fields[0];
            }
        }
    }

    FileView {
        id: current

        path: root.device ? `/sys/class/backlight/${root.device}/brightness` : ""
        blockAllReads: true
    }

    Process {
        id: writer

        onExited: Qt.callLater(root.flush)
    }
}
