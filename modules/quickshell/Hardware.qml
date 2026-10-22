pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the stats read, found once at start: the sensors' files, each GPU with
// its files and connectors, and the memory modules.
Singleton {
    id: root

    property string cpuTemp
    property var dimmTemps: []
    // By disk name.
    property var diskTemps: ({})
    // {pci, driver, integrated, model, files: {name: path}, connectors: [path]}
    property var gpus: []
    // The installed modules, as udev's MEMORY_DEVICE_<n>_* properties without
    // the prefix: {SIZE, TYPE, SPEED_MTS, LOCATOR, ...}.
    property var modules: []
    property bool found: false

    // A sysfs or procfs file's contents, trimmed, or "" when missing.
    function read(path) {
        if (reader.path === path)
            reader.reload();
        else
            reader.path = path;
        return reader.text().trim();
    }

    // A file's number divided by `scale`, or NaN.
    function number(path, scale) {
        const text = path ? read(path) : "";
        return text === "" ? NaN : Number(text) / (scale ?? 1);
    }

    FileView {
        id: reader

        blockAllReads: true
        printErrors: false
    }

    Process {
        running: true
        command: [Programs.statsProbe, "hardware"]
        stdout: StdioCollector {
            onStreamFinished: {
                const dimms = [], disks = {}, gpus = {}, modules = {};
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f[0] === "cpu-temp" && root.cpuTemp === "")
                        root.cpuTemp = f[1];
                    else if (f[0] === "dimm-temp")
                        dimms.push(f[1]);
                    else if (f[0] === "disk-temp")
                        disks[f[1]] = f[2];
                    else if (f[0] === "gpu")
                        gpus[f[1]] = {
                            pci: f[1],
                            driver: f[2],
                            integrated: f[3] === "1",
                            model: f[4],
                            files: {},
                            connectors: []
                        };
                    else if (f[0] === "gpu-file" && !(f[2] in gpus[f[1]].files))
                        gpus[f[1]].files[f[2]] = f[3];
                    else if (f[0] === "connector")
                        gpus[f[1]].connectors.push(f[2]);
                    else if (f[0] === "memory") {
                        const m = f[1].match(/^MEMORY_DEVICE_(\d+)_(\w+)=(.*)$/);
                        if (m) {
                            modules[m[1]] = modules[m[1]] ?? {};
                            modules[m[1]][m[2]] = m[3];
                        }
                    }
                }
                root.dimmTemps = dimms;
                root.diskTemps = disks;
                root.gpus = Object.values(gpus);
                root.modules = Object.values(modules).filter(m => Number(m.SIZE) > 0);
                root.found = true;
            }
        }
    }
}
