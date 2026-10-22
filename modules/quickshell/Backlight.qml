pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The backlight brightnessctl picks by default, as the brightness keys do, and
// its adaptive backlight management. Both sysfs files are root's, so the level
// goes through brightnessctl and ABM through a unit the session may start.
Singleton {
    id: root

    // Empty where there is no backlight.
    property string device
    property int max
    // Raw, as last read or set.
    property int level
    readonly property int percent: max > 0 ? Math.round(level * 100 / max) : 0
    // ABM, 0 for off to 4, as last read or set; -1 where the panel has none.
    // TLP sets it with each profile, overriding a level set here.
    property int abm: -1

    signal stepped

    // Skips a value with a write in flight, since reading it would undo the write.
    function read() {
        if (device === "")
            return;
        if (!writer.busy) {
            current.reload();
            level = parseInt(current.text());
        }
        if (!abmWriter.busy) {
            abmFile.reload();
            abm = abmFile.loaded ? parseInt(abmFile.text()) : -1;
        }
    }

    // Never below 1%, whether from the power panel, the brightness keys or
    // power-saver.
    function set(raw) {
        if (device === "")
            return;
        level = Math.max(Math.round(max / 100), Math.min(max, raw));
        writer.submit([Programs.brightnessctl, "-q", "-d", device, "set", String(level)]);
    }

    function setPercent(percent) {
        set(Math.round(percent * max / 100));
    }

    // By `delta` percent of the level as it is now, for the brightness keys,
    // which the OSD follows.
    function step(delta) {
        if (device === "")
            return;
        read();
        setPercent(percent + delta);
        stepped();
    }

    function setAbm(value) {
        if (abm < 0 || value === abm)
            return;
        abm = value;
        abmWriter.submit([Programs.systemctl, "start", `adaptive-backlight@${value}.service`]);
    }

    // Runs one command at a time. One submitted meanwhile waits, and a newer
    // one replaces it.
    component Queue: Process {
        id: queue

        property var next: null
        readonly property bool busy: running || next !== null

        function submit(command) {
            next = command;
            if (!running)
                flush();
        }

        function flush() {
            if (next === null)
                return;
            command = next;
            next = null;
            running = true;
        }

        onExited: Qt.callLater(queue.flush)
    }

    // device,class,current,percent,max. Without a class, brightnessctl falls
    // back to a keyboard LED where there is no backlight.
    Process {
        running: true
        command: [Programs.brightnessctl, "-m", "-c", "backlight"]
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

    // The backlight's device is the panel's connector.
    FileView {
        id: abmFile

        path: root.device ? `/sys/class/backlight/${root.device}/device/amdgpu/panel_power_savings` : ""
        blockAllReads: true
        printErrors: false
    }

    IpcHandler {
        target: "backlight"

        function up(): void {
            root.step(10);
        }

        function down(): void {
            root.step(-10);
        }
    }

    Queue {
        id: writer
    }

    Queue {
        id: abmWriter
    }
}
