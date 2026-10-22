pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Each app's cpu and memory, from its cgroups, which name an app by its unit:
// every Vivaldi process counts as one Vivaldi. Sampled while a tooltip shows it.
Singleton {
    id: root

    // {name, cpu, memory}: cpu as a share of the whole CPU since the last
    // sample, memory in bytes, anonymous and shared.
    property var apps: []
    property var last: null
    property var names: ({})

    // The desktop entry's name for an app key, else the key. A reverse-DNS
    // key, as a Chromium browser names the scope of its helpers, matches an
    // entry by its last part. Only a match is kept: the entries load after the
    // bar starts.
    function name(key) {
        if (!(key in names)) {
            const last = key.split(".").pop().toLowerCase();
            const entry = DesktopEntries.heuristicLookup(key) ?? (key.includes(".") ? DesktopEntries.applications.values.find(e => e.id.toLowerCase().startsWith(last)) : null);
            if (!entry)
                return key;
            names[key] = entry.name;
        }
        return names[key];
    }

    function sample() {
        probe.running = true;
    }

    Process {
        id: probe

        command: [Programs.statsProbe, "apps"]
        stdout: StdioCollector {
            onStreamFinished: {
                const now = Date.now(), usage = {}, memory = {};
                for (const line of text.split("\n")) {
                    const f = line.split("\t");
                    if (f.length < 3)
                        continue;
                    const name = root.name(f[0]);
                    usage[name] = (usage[name] ?? 0) + Number(f[1]);
                    memory[name] = (memory[name] ?? 0) + Number(f[2]);
                }
                // A baseline from a tooltip opened earlier would average over the time
                // it was closed.
                const base = root.last && now - root.last.at < 5000 ? root.last : null;
                const capacity = base ? (now - base.at) * 1000 * Math.max(1, Stats.cores.length) : 0;
                root.apps = Object.keys(usage).map(name => ({
                            name,
                            cpu: capacity > 0 ? 100 * Math.max(0, usage[name] - (base.usage[name] ?? usage[name])) / capacity : NaN,
                            memory: memory[name]
                        }));
                root.last = {
                    at: now,
                    usage
                };
            }
        }
    }
}
