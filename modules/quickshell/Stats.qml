pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

// The cpu, memory, disk and network figures, sampled once for every bar.
Singleton {
    id: root

    property int cpu
    property string cpuTooltip
    property int memory
    property string memoryTooltip
    property int disk
    property string diskTooltip
    // True once a sample has found no device to read.
    property bool offline: false
    // Rates as `rate` formats them, and the last minute of them in bytes per
    // second, oldest first.
    property string up
    property string down
    property var upHistory: []
    property var downHistory: []
    // Per core, in /proc/stat order.
    property var cores: []

    // NetworkManager gives wired the lower route metric.
    readonly property NetworkDevice networkDevice: {
        const up = Networking.devices.values.filter(d => d.connected && (d.type === DeviceType.Wired || d.type === DeviceType.Wifi));
        return up.find(d => d.type === DeviceType.Wired) ?? up[0] ?? null;
    }

    property var cpuTimes: []
    property var counters: null

    // Binary sizes to one decimal, with a lowercase k.
    function size(bytes) {
        const units = ["", "ki", "Mi", "Gi", "Ti", "Pi"];
        let i = 0;
        for (; i < units.length - 1 && bytes >= 1024; i++)
            bytes /= 1024;
        return `${bytes.toFixed(1)}${units[i]}B`;
    }

    // Decimal units, in bytes despite the b.
    function rate(bytes) {
        for (const [unit, divisor] of [["Gb/s", 1e9], ["Mb/s", 1e6], ["Kb/s", 1e3]])
            if (bytes >= divisor)
                return `${String(Math.trunc(bytes / divisor)).padStart(3)} ${unit}`;
        return `${String(Math.trunc(bytes)).padStart(3)}  b/s`;
    }

    function sampleCpu() {
        stat.reload();
        const times = stat.text().split("\n").filter(l => l.startsWith("cpu")).map(l => {
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
            cpuTooltip = [`Total: ${usage[0]}%`].concat(usage.slice(1).map((u, i) => `Core${i}: ${u}%`)).join("\n");
        }
        cpuTimes = times;
    }

    function sampleMemory() {
        meminfo.reload();
        const kib = {};
        for (const line of meminfo.text().split("\n")) {
            const m = line.match(/^(\w+):\s+(\d+)/);
            if (m)
                kib[m[1]] = Number(m[2]);
        }
        const used = kib.MemTotal - kib.MemAvailable;
        const gib = k => (Math.round(k / 10485.76) / 100).toFixed(1);
        memory = Math.trunc(100 * used / kib.MemTotal);
        memoryTooltip = `Used: ${memory}%, ${gib(used)}GiB / ${gib(kib.MemTotal)}GiB`;
    }

    function sampleNetwork() {
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
        id: stat

        path: "/proc/stat"
        blockAllReads: true
    }

    FileView {
        id: meminfo

        path: "/proc/meminfo"
        blockAllReads: true
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
        onTriggered: root.sampleCpu()
    }

    Timer {
        interval: 10000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            root.sampleCpu();
            root.sampleMemory();
        }
    }

    Timer {
        interval: 30000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: df.running = true
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
        id: df

        command: [Programs.df, "--block-size=1", "--output=size,used,avail", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const [total, used, avail] = text.trim().split("\n")[1].trim().split(/\s+/).map(Number);
                root.disk = Math.trunc(used * 100 / total);
                root.diskTooltip = `Free: ${root.size(avail)}\nUsed: ${root.disk}%, ${root.size(used)} / ${root.size(total)}`;
            }
        }
    }
}
