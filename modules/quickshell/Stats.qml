pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// The cpu, memory, disk and network figures, sampled once for every bar. The
// bar's figures refresh on their own timers; a tooltip polls the details it
// shows while it is open.
Singleton {
    id: root

    property int cpu
    // Per thread, in /proc/stat order.
    property var cores: []
    // The total every ten seconds, the last five minutes of it, oldest first.
    property var cpuHistory: []
    property string cpuModel
    // The GPU /proc/cpuinfo names after the model, as an APU's does.
    property string cpuGraphics
    // Each physical core's threads, as indices into `cores`.
    property var physicalCores: []
    // Per thread, in MHz.
    property var clocks: []
    property real maxClock: NaN
    property real cpuTemp: NaN
    // The 1, 5 and 15 minute load averages.
    property var load: []
    property real uptime

    property int memory
    // In bytes. Used, cache and free add up to the total; cache is what the
    // kernel can reclaim.
    property real memoryTotal
    property real memoryUsed
    property real memoryCache
    property real memoryFree
    property real swapTotal
    property real swapUsed
    property var dimmTemps: []

    // The root filesystem's use, and whether it or /boot has reached 90%.
    property int disk
    property bool diskFull: false
    // Each drive with a mounted filesystem: {name, model, size, temp, health,
    // filesystems: [{mount, type, size, used, avail}]}.
    property var drives: []
    // By drive name: {read, write} in bytes per second, and their histories
    // every ten seconds.
    property var io: ({})
    // {number, time} by number.
    property var generations: []

    // True once a sample has found no device to read.
    property bool offline: false
    // True from the first network sample on.
    property bool sampled: false
    // Rates as `rate` formats them, and the last minute of them in bytes per
    // second, oldest first.
    property string up
    property string down
    property var upHistory: []
    property var downHistory: []

    // NetworkManager gives wired the lower route metric.
    readonly property NetworkDevice networkDevice: {
        const up = Networking.devices.values.filter(d => d.connected && (d.type === DeviceType.Wired || d.type === DeviceType.Wifi));
        return up.find(d => d.type === DeviceType.Wired) ?? up[0] ?? null;
    }

    property var cpuTimes: []
    property var counters: null
    property var ioCounters: ({})

    // Binary sizes, to one decimal below 100, with a lowercase k.
    function size(bytes) {
        const units = ["", "ki", "Mi", "Gi", "Ti", "Pi"];
        let i = 0;
        for (; i < units.length - 1 && bytes >= 1024; i++)
            bytes /= 1024;
        return `${i > 0 && bytes < 100 ? bytes.toFixed(1) : Math.round(bytes)} ${units[i]}B`;
    }

    // Decimal units, in bytes despite the b.
    function rate(bytes) {
        for (const [unit, divisor] of [["Gb/s", 1e9], ["Mb/s", 1e6], ["Kb/s", 1e3]])
            if (bytes >= divisor)
                return `${Math.trunc(bytes / divisor)} ${unit}`;
        return `${Math.trunc(bytes)} b/s`;
    }

    // A share, to one decimal from 0.1 to 10.
    function percent(value) {
        return `${value >= 0.05 && value < 10 ? value.toFixed(1) : Math.round(value)}%`;
    }

    // Yellow from `warn`, red from `crit`, otherwise `normal`.
    function tempColor(celsius, warn, crit, normal) {
        return celsius >= crit ? Theme.red : celsius >= warn ? Theme.yellow : normal ?? Theme.foregroundMuted;
    }

    function sampleCpu() {
        const times = Hardware.read("/proc/stat").split("\n").filter(l => l.startsWith("cpu")).map(l => {
            const t = l.trim().split(/\s+/).slice(1).map(Number);
            return {
                idle: t[3] + t[4],
                total: t.reduce((a, b) => a + b, 0)
            };
        });
        if (cpuTimes.length === times.length) {
            const usage = times.map((t, i) => Math.trunc(100 * (1 - (t.idle - cpuTimes[i].idle) / Math.max(1, t.total - cpuTimes[i].total))));
            cpu = usage[0];
            cores = usage.slice(1);
        }
        cpuTimes = times;
    }

    // The clocks, temperature, load and uptime, and on the first call the
    // model and topology, all of which only the tooltip shows.
    function sampleCpuDetails() {
        const threads = Hardware.read("/proc/cpuinfo").split("\n\n").filter(b => b.includes("processor")).map(b => {
            const t = {};
            for (const line of b.split("\n")) {
                const m = line.match(/^([^:]+?)\s*:\s*(.*)$/);
                if (m)
                    t[m[1]] = m[2];
            }
            return t;
        });
        clocks = threads.map(t => Number(t["cpu MHz"]));
        if (cpuModel === "" && threads.length > 0) {
            maxClock = Hardware.number("/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq", 1000);
            const name = threads[0]["model name"] ?? "";
            cpuGraphics = name.match(/ w\/ (.+?)(?: Graphics)?$/)?.[1] ?? "";
            cpuModel = name.replace(/\((R|TM)\)/g, "").replace(/ w\/ .*$/, "").replace(/ with .*Graphics$/, "").replace(/ \d+-Core Processor$/, "").replace(/\s+/g, " ").trim();
            const byCore = {};
            threads.forEach((t, i) => {
                const id = `${t["physical id"]}:${t["core id"]}`;
                (byCore[id] = byCore[id] ?? []).push(i);
            });
            physicalCores = Object.values(byCore).sort((a, b) => a[0] - b[0]);
        }
        cpuTemp = Hardware.number(Hardware.cpuTemp, 1000);
        load = Hardware.read("/proc/loadavg").split(" ").slice(0, 3).map(Number);
        uptime = Number(Hardware.read("/proc/uptime").split(" ")[0]);
    }

    function sampleMemory() {
        const kib = {};
        for (const line of Hardware.read("/proc/meminfo").split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                kib[m[1]] = Number(m[2]) * 1024;
        }
        memoryTotal = kib.MemTotal;
        memoryUsed = kib.MemTotal - kib.MemAvailable;
        memoryFree = kib.MemFree;
        memoryCache = Math.max(0, kib.MemAvailable - kib.MemFree);
        memory = Math.trunc(100 * memoryUsed / memoryTotal);
        swapTotal = kib.SwapTotal ?? 0;
        swapUsed = swapTotal - (kib.SwapFree ?? 0);
    }

    function sampleDimms() {
        dimmTemps = Hardware.dimmTemps.map(p => Hardware.number(p, 1000)).filter(t => !isNaN(t));
    }

    // Read and write rates since the last call, from each drive's sector
    // counters, appended to the histories on the ten-second tick.
    function sampleIo(record) {
        const now = Date.now(), next = Object.assign({}, io), counters = {};
        for (const drive of drives) {
            const f = Hardware.read(`/sys/block/${drive.name}/stat`).split(/\s+/).map(Number);
            if (f.length < 7)
                continue;
            counters[drive.name] = {
                read: f[2] * 512,
                write: f[6] * 512,
                at: now
            };
            const last = ioCounters[drive.name];
            const entry = Object.assign({
                read: 0,
                write: 0,
                readHistory: [],
                writeHistory: []
            }, next[drive.name]);
            if (last) {
                const seconds = Math.max(0.001, (now - last.at) / 1000);
                entry.read = (counters[drive.name].read - last.read) / seconds;
                entry.write = (counters[drive.name].write - last.write) / seconds;
            }
            if (record && last) {
                entry.readHistory = entry.readHistory.concat([entry.read]).slice(-30);
                entry.writeHistory = entry.writeHistory.concat([entry.write]).slice(-30);
            }
            next[drive.name] = entry;
        }
        ioCounters = counters;
        io = next;
    }

    // Each drive's model, filesystems, temperature and health, from lsblk and
    // the drive-health service's smartctl output.
    function sampleDrives() {
        lsblk.running = true;
    }

    function health(name) {
        let j;
        try {
            j = JSON.parse(Hardware.read(`/run/drive-health/${name}.json`));
        } catch (e) {
            return null;
        }
        const nvme = j.nvme_smart_health_information_log;
        const ata = {};
        for (const a of j.ata_smart_attributes?.table ?? [])
            ata[a.id] = a.raw?.value ?? 0;
        return {
            passed: j.smart_status?.passed ?? null,
            hours: j.power_on_time?.hours ?? NaN,
            // The drive's own temperature limits.
            tempWarn: j.temperature?.op_limit_max ?? NaN,
            tempCrit: j.temperature?.critical_limit_max ?? NaN,
            critical: nvme?.critical_warning ?? 0,
            spare: nvme?.available_spare ?? NaN,
            spareThreshold: nvme?.available_spare_threshold ?? NaN,
            worn: nvme?.percentage_used ?? NaN,
            written: nvme ? nvme.data_units_written * 512000 : NaN,
            mediaErrors: nvme?.media_errors ?? 0,
            reallocated: ata[5] ?? 0,
            pending: ata[197] ?? 0
        };
    }

    function sampleGenerations() {
        generationProbe.running = true;
    }

    function sampleNetwork() {
        sampled = true;
        if (!networkDevice) {
            counters = null;
            offline = true;
            return;
        }
        offline = false;
        rx.reload();
        tx.reload();
        const now = {
            rx: parseInt(rx.text()),
            tx: parseInt(tx.text()),
            at: Date.now()
        };
        if (isNaN(now.rx) || isNaN(now.tx)) {
            counters = null;
            return;
        }
        if (counters) {
            const seconds = (now.at - counters.at) / 1000;
            const upRate = (now.tx - counters.tx) / seconds;
            const downRate = (now.rx - counters.rx) / seconds;
            up = rate(upRate);
            down = rate(downRate);
            upHistory = upHistory.concat([upRate]).slice(-30);
            downHistory = downHistory.concat([downRate]).slice(-30);
        }
        counters = now;
    }

    // A new device starts a new baseline, once the counter paths follow it;
    // its rate shows on the next tick.
    onNetworkDeviceChanged: {
        counters = null;
        up = "";
        down = "";
        upHistory = [];
        downHistory = [];
        Qt.callLater(sampleNetwork);
    }

    FileView {
        id: rx

        path: root.networkDevice ? `/sys/class/net/${root.networkDevice.name}/statistics/rx_bytes` : ""
        blockAllReads: true
    }

    FileView {
        id: tx

        path: root.networkDevice ? `/sys/class/net/${root.networkDevice.name}/statistics/tx_bytes` : ""
        blockAllReads: true
    }

    // The first cpu figure, 100 ms after the baseline rather than one interval.
    Timer {
        interval: 100
        running: true
        onTriggered: {
            root.sampleCpu();
            root.sampleCpuDetails();
        }
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.sampleCpu();
            root.cpuHistory = root.cpuHistory.concat([root.cpu]).slice(-30);
            root.sampleMemory();
            root.sampleIo(true);
            Gpus.sample(true);
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.sampleDrives()
    }

    // Not on start: NetworkManager's devices arrive just after, and sampling
    // before them would flash the offline state.
    Timer {
        interval: 2000
        running: true
        repeat: true
        onTriggered: root.sampleNetwork()
    }

    Process {
        id: lsblk

        command: [Programs.lsblk, "--json", "--bytes", "--output", "NAME,TYPE,MODEL,SIZE,FSTYPE,MOUNTPOINTS,FSSIZE,FSUSED,FSAVAIL"]
        stdout: StdioCollector {
            onStreamFinished: {
                let devices;
                try {
                    devices = JSON.parse(text).blockdevices;
                } catch (e) {
                    return;
                }
                // A bind mount lists its source's filesystem again, so each
                // takes its shortest mount point.
                const filesystems = device => {
                    const own = (device.mountpoints ?? []).filter(m => m?.startsWith("/")).sort((a, b) => a.length - b.length);
                    const fs = own.length > 0 && device.fssize > 0 ? [
                        {
                            mount: own[0],
                            type: device.fstype,
                            size: device.fssize,
                            used: device.fsused,
                            avail: device.fsavail
                        }
                    ] : [];
                    return fs.concat(...(device.children ?? []).map(filesystems));
                };
                const drives = devices.filter(d => d.type === "disk").map(d => ({
                            name: d.name,
                            model: (d.model ?? d.name).replace(/\s+\S*\d\S*-\S+$/, "").trim(),
                            size: d.size,
                            temp: Hardware.number(Hardware.diskTemps[d.name], 1000),
                            health: root.health(d.name),
                            filesystems: filesystems(d).sort((a, b) => a.mount.localeCompare(b.mount))
                        })).filter(d => d.filesystems.length > 0);
                const all = [].concat(...drives.map(d => d.filesystems));
                const rootFs = all.find(f => f.mount === "/");
                if (rootFs)
                    root.disk = Math.trunc(100 * rootFs.used / rootFs.size);
                root.diskFull = all.some(f => (f.mount === "/" || f.mount === "/boot") && f.used >= 0.9 * f.size);
                const first = root.drives.length === 0;
                root.drives = drives;
                if (first)
                    root.sampleIo(false);
            }
        }
    }

    Process {
        id: generationProbe

        command: [Programs.statsProbe, "generations"]
        stdout: StdioCollector {
            onStreamFinished: root.generations = text.trim().split("\n").filter(l => l !== "").map(l => {
                const [number, time] = l.split("\t").map(Number);
                return {
                    number,
                    time: new Date(time * 1000)
                };
            }).sort((a, b) => a.number - b.number)
        }
    }
}
