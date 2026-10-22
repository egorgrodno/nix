pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Each GPU's figures: amdgpu's from sysfs, NVIDIA's from nvidia-smi, sampled
// with the cpu on the bar's tick and polled while the tooltip is open.
Singleton {
    id: root

    // Those driving a screen first: {pci, driver, integrated, name, drives,
    // busy, video, decode, encode, vramUsed, vramTotal, gttUsed, gttTotal,
    // temp, hotspot, power, powerCap, clock, fan, fanUnit, throttle, history,
    // apps}. Temperatures in °C, power in W, clocks in MHz, memory in bytes,
    // `fanUnit` "%" or " rpm", `throttle` the reasons the clocks are held
    // down, `apps` [{name, busy, memory}].
    property var gpus: []
    readonly property var primary: gpus[0] ?? null
    property var state: ({})
    // By NVIDIA index, as pmon numbers the GPUs.
    property var nvidiaPci: ({})
    // The optional ones go once a driver refuses them.
    property var nvidiaFields: ["index", "pci.bus_id", "name", "utilization.gpu", "memory.used", "memory.total", "temperature.gpu", "power.draw", "enforced.power.limit", "clocks.gr", "fan.speed", "utilization.decoder", "utilization.encoder", "clocks_event_reasons.active"]
    readonly property int nvidiaRequired: 11
    // Each DRM client's engine time at the last poll: {"<pci> <client>": ns}.
    property var clientTimes: ({})
    property real clientsAt: 0

    function name(gpu) {
        const vendor = {
            amdgpu: "AMD",
            radeon: "AMD",
            i915: "Intel",
            xe: "Intel",
            nouveau: "NVIDIA",
            nvidia: "NVIDIA"
        }[gpu.driver] ?? "";
        if (gpu.integrated && Stats.cpuGraphics !== "")
            return `${vendor} ${Stats.cpuGraphics}`;
        const bracketed = gpu.model.match(/\[(.+)\]/)?.[1];
        if (bracketed)
            return `${vendor} ${bracketed}`;
        return `${vendor === "AMD" ? "AMD Radeon" : vendor} Graphics${gpu.model ? ` (${gpu.model})` : ""}`;
    }

    function publish(next) {
        state = next;
        gpus = Object.values(next).sort((a, b) => b.drives - a.drives);
    }

    function sample(record) {
        const next = {};
        for (const g of Hardware.gpus) {
            const s = Object.assign({
                history: [],
                apps: [],
                throttle: []
            }, state[g.pci], {
                pci: g.pci,
                driver: g.driver,
                integrated: g.integrated,
                drives: g.connectors.some(p => Hardware.read(p) === "connected")
            });
            if (g.driver === "nvidia")
                s.name = s.name ?? root.name(g);
            else {
                s.name = root.name(g);
                const f = (key, scale) => Hardware.number(g.files[key], scale);
                Object.assign(s, {
                    busy: f("busy"),
                    video: f("video"),
                    vramUsed: f("vramUsed"),
                    vramTotal: f("vramTotal"),
                    gttUsed: f("gttUsed"),
                    gttTotal: f("gttTotal"),
                    temp: f("temp", 1000),
                    hotspot: f("hotspot", 1000),
                    power: f("power", 1e6),
                    powerCap: f("powerCap", 1e6),
                    clock: f("clock", 1e6),
                    fan: f("fan"),
                    fanUnit: " rpm"
                });
            }
            if (record && !isNaN(s.busy))
                s.history = s.history.concat([s.busy]).slice(-30);
            next[g.pci] = s;
        }
        publish(next);
        if (Programs.nvidiaSmi !== "" && Hardware.gpus.some(g => g.driver === "nvidia"))
            nvidiaQuery.running = true;
    }

    // Each app's share of each GPU and its memory there.
    function sampleClients() {
        if (Hardware.gpus.some(g => g.driver !== "nvidia"))
            drmClients.running = true;
        if (Programs.nvidiaSmi !== "" && Hardware.gpus.some(g => g.driver === "nvidia"))
            nvidiaClients.running = true;
    }

    // Sums each app's figures for each GPU into its `apps`.
    function setApps(byPci) {
        const next = Object.assign({}, state);
        for (const pci in byPci)
            if (next[pci])
                next[pci] = Object.assign({}, next[pci], {
                    apps: Object.entries(byPci[pci]).map(([name, a]) => Object.assign({
                                name
                            }, a))
                });
        publish(next);
    }

    function add(byPci, pci, key, busy, memory) {
        const name = AppUsage.name(key);
        const apps = byPci[pci] = byPci[pci] ?? {};
        const a = apps[name] = apps[name] ?? {
            busy: 0,
            memory: 0
        };
        a.busy += busy;
        a.memory += memory;
    }

    // The bar shows the GPU module once the first sample finds one.
    Connections {
        target: Hardware

        function onFoundChanged() {
            root.sample(false);
        }
    }

    Process {
        id: nvidiaQuery

        command: [Programs.nvidiaSmi, `--query-gpu=${root.nvidiaFields.join(",")}`, "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const next = Object.assign({}, root.state), pci = {};
                for (const line of text.split("\n")) {
                    const f = line.split(",").map(s => s.trim());
                    if (f.length < root.nvidiaFields.length)
                        continue;
                    const v = {};
                    root.nvidiaFields.forEach((field, i) => v[field] = f[i]);
                    const bus = v["pci.bus_id"].slice(-12).toLowerCase();
                    pci[v.index] = bus;
                    if (!next[bus])
                        continue;
                    const reasons = parseInt(v["clocks_event_reasons.active"], 16);
                    next[bus] = Object.assign({}, next[bus], {
                        name: v.name,
                        busy: Number(v["utilization.gpu"]),
                        decode: Number(v["utilization.decoder"]),
                        encode: Number(v["utilization.encoder"]),
                        vramUsed: Number(v["memory.used"]) * 1048576,
                        vramTotal: Number(v["memory.total"]) * 1048576,
                        temp: Number(v["temperature.gpu"]),
                        power: Number(v["power.draw"]),
                        powerCap: Number(v["enforced.power.limit"]),
                        clock: Number(v["clocks.gr"]),
                        fan: Number(v["fan.speed"]),
                        fanUnit: "%",
                        // NVML's clock event reasons: the software power cap,
                        // software and hardware thermal slowdown, and the
                        // hardware slowdown and power brake.
                        throttle: isNaN(reasons) ? [] : [[0x4, "power limit"], [0x60, "temperature"], [0x88, "hardware slowdown"]].filter(([bit]) => reasons & bit).map(([, reason]) => reason)
                    });
                }
                root.nvidiaPci = pci;
                root.publish(next);
            }
        }
        onExited: code => {
            if (code !== 0 && root.nvidiaFields.length > root.nvidiaRequired)
                root.nvidiaFields = root.nvidiaFields.slice(0, root.nvidiaRequired);
        }
    }

    Process {
        id: drmClients

        command: [Programs.statsProbe, "drm-clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                const now = Date.now(), times = {}, byPci = {};
                // NVIDIA's clients come from pmon.
                for (const g of Hardware.gpus)
                    if (g.driver !== "nvidia")
                        byPci[g.pci] = {};
                // A baseline from a tooltip opened earlier would average over
                // the time it was closed.
                const elapsed = now - root.clientsAt < 5000 ? (now - root.clientsAt) * 1e6 : 0;
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f.length < 6 || !(f[0] in byPci))
                        continue;
                    const pci = f[0], id = `${pci} ${f[2]}`;
                    times[id] = Number(f[3]);
                    const busy = elapsed > 0 && id in root.clientTimes ? 100 * Math.max(0, times[id] - root.clientTimes[id]) / elapsed : 0;
                    const shared = root.state[pci]?.integrated ? Number(f[5]) : 0;
                    root.add(byPci, pci, f[1], busy, Number(f[4]) + shared);
                }
                root.clientTimes = times;
                root.clientsAt = now;
                root.setApps(byPci);
            }
        }
    }

    Process {
        id: nvidiaClients

        command: [Programs.statsProbe, "nvidia-clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                const byPci = {};
                for (const g of Hardware.gpus)
                    if (g.driver === "nvidia")
                        byPci[g.pci] = {};
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    const pci = root.nvidiaPci[f[0]];
                    if (f.length >= 5 && pci)
                        root.add(byPci, pci, f[1], Number(f[3]), Number(f[4]) * 1048576);
                }
                root.setApps(byPci);
            }
        }
    }
}
