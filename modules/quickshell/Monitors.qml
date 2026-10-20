pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// The connected monitors as `hyprctl monitors all` reports them, the only view
// that keeps a disabled one, and a layout saved for each set of them, keyed by
// their descriptions. Whenever the set changes, or a config reload brings back
// the configuration's own monitor rules, the set's layout applies. A set that
// connects to the running bar with no layout saved posts a notification that
// opens the panel. A layout from the panel applies at once and reverts after
// 15 s unless kept, which saves it.
//
// Clamshell: while the lid is closed on another monitor that the open lid's
// layout keeps on, the laptop's panel is off and out of the set, which then
// has a layout of its own. Losing the last other monitor ends it after a 3 s
// grace, which a TV blinking off rides out. Until the panel is on again a
// `handle-lid-switch` inhibitor holds logind off, so the laptop never suspends
// with every screen dark.
Singleton {
    id: root

    property var outputs: []
    // By set key, a spec per monitor, its output and mirror as descriptions.
    property var layouts: ({})
    // The set keys whose displays keep the session awake: hypridle honours
    // the systemd idle inhibitor held while one is connected.
    property var awake: []
    property bool lidClosed: false
    // Until logind answers no layout applies, as one taking the lid for open
    // would light a closed panel.
    property bool lidRead: false
    property bool clamshell: false
    // The set whose layout last applied: Hyprland reports a monitor a layout
    // disables or enables as removed or added, which must not apply it again.
    property string appliedKey: ""
    property bool reloaded: false
    // While a layout from the panel waits to be kept, the specs it replaced.
    property var previous: null
    property var pending: null
    property int remaining: 0
    // The cursor's monitor as a layout applies, and its place on it as
    // fractions of the monitor's size. A layout that moves or resizes that
    // monitor takes the cursor along, which would otherwise keep its position
    // over whichever monitor lies there now. Hyprland applies a rule a moment
    // after the eval, so a few refreshes look for the change.
    property var cursor: null
    // The eval waiting on the cursor's position.
    property string chunk
    // The outputs to arrange, the laptop's panel left out in clamshell.
    readonly property var present: clamshell ? outputs.filter(o => !internal(o)) : outputs
    readonly property string currentKey: key(present)
    readonly property bool saved: currentKey in layouts
    readonly property bool stayAwake: awake.includes(currentKey)

    signal toggleRequested

    function key(list) {
        return list.map(describe).sort().join("\n");
    }

    // A headless output has no description.
    function describe(output) {
        return output.description || output.name;
    }

    // The laptop's own panel, told apart by its connector as logind does.
    function internal(output) {
        return /^(eDP|LVDS|DSI)-/.test(output.name);
    }

    // Whether a monitor besides the laptop's panel, and not a headless
    // output, is on in the layout for all of them, which the open lid has.
    function docked() {
        const layout = layouts[key(outputs)];
        return outputs.some(o => {
            const s = layout?.find(s => s.output === describe(o));
            return !internal(o) && o.description && !(s ?? o).disabled;
        });
    }

    // { width, height, rate, mode }, in Hyprland's order, the mode as
    // hl.monitor takes it. Once each, as a display can list a mode twice.
    function modes(output) {
        return [...new Set(output.availableModes)].map(m => {
            const [, width, height, rate] = m.match(/^(\d+)x(\d+)@([\d.]+)Hz$/);
            return {
                width: Number(width),
                height: Number(height),
                rate: Number(rate),
                mode: `${width}x${height}@${rate}`
            };
        });
    }

    // Every field, as a rule keeps whatever its predecessor set that it leaves
    // out: only `disabled = false` enables a monitor again, and only an empty
    // mirror ends a mirror.
    function spec(output, mode, x, y, scale, transform, disabled, mirror) {
        return {
            output: output,
            mode: mode,
            position: `${x}x${y}`,
            scale: scale,
            transform: transform,
            disabled: disabled,
            mirror: mirror
        };
    }

    // An output's state as a spec, its mode the listed one nearest its rate.
    // Hyprland reports a mirror by the mirrored monitor's id.
    function specOf(output) {
        const mode = modes(output).filter(m => m.width === output.width && m.height === output.height).sort((a, b) => Math.abs(a.rate - output.refreshRate) - Math.abs(b.rate - output.refreshRate))[0];
        const mirrored = outputs.find(o => String(o.id) === output.mirrorOf);
        return spec(output.name, mode?.mode ?? `${output.width}x${output.height}@${output.refreshRate}`, output.x, output.y, output.scale, output.transform, output.disabled, mirrored?.name ?? "");
    }

    // Hyprland reports a scale to two places.
    function same(a, b) {
        return Object.keys(a).every(k => k === "scale" ? Math.abs(a.scale - b.scale) < 0.01 : a[k] === b[k]);
    }

    function lua(value) {
        if (typeof value === "string")
            return JSON.stringify(value);
        if (typeof value !== "object")
            return String(value);
        return `{ ${Object.entries(value).map(([k, v]) => `${k} = ${lua(v)}`).join(", ")} }`;
    }

    // In one eval, the specs that differ from the outputs' state, or all.
    function apply(specs, all) {
        const changed = all ? specs : specs.filter(s => {
            const output = outputs.find(o => o.name === s.output);
            return !output || !same(s, specOf(output));
        });
        if (changed.length === 0)
            return;
        chunk = changed.map(s => `hl.monitor(${lua(s)})`).join("\n");
        locator.running = true;
    }

    // In logical pixels, a quarter turn swapping the sides.
    function rectOf(output) {
        const turned = output.transform % 2 === 1;
        return {
            x: output.x,
            y: output.y,
            width: (turned ? output.height : output.width) / output.scale,
            height: (turned ? output.width : output.height) / output.scale
        };
    }

    // Shown on its own, neither off nor mirroring another.
    function placed(output) {
        return !output.disabled && output.mirrorOf === "none";
    }

    function follow() {
        const output = outputs.find(o => o.name === cursor.name && placed(o));
        const r = output ? rectOf(output) : null;
        const moved = r && ["x", "y", "width", "height"].some(k => Math.abs(r[k] - cursor.rect[k]) > 0.5);
        if (moved)
            Quickshell.execDetached([Programs.hyprctl, "eval", `hl.dispatch(hl.dsp.cursor.move({ x = ${Math.round(r.x + cursor.fx * r.width)}, y = ${Math.round(r.y + cursor.fy * r.height)} }))`]);
        if (!output || moved || ++cursor.tries >= 3)
            cursor = null;
        else
            refresh();
    }

    // A saved layout for the outputs connected now, its descriptions matched
    // to their names, monitors alike taken in the order of their names.
    function resolve(layout) {
        const free = [...present].sort((a, b) => a.name.localeCompare(b.name));
        const names = {};
        const specs = layout.map(s => {
            const i = free.findIndex(o => describe(o) === s.output);
            const output = free.splice(i, 1)[0];
            names[s.output] = names[s.output] ?? output.name;
            return Object.assign({}, s, {
                output: output.name
            });
        });
        return specs.map(s => Object.assign(s, {
                mirror: s.mirror === "" ? "" : names[s.mirror] ?? ""
            }));
    }

    function save(specs) {
        const descriptions = {};
        for (const output of outputs)
            descriptions[output.name] = describe(output);
        layouts = Object.assign({}, layouts, {
            [currentKey]: specs.map(s => Object.assign({}, s, {
                    output: descriptions[s.output],
                    mirror: s.mirror === "" ? "" : descriptions[s.mirror]
                }))
        });
        store();
    }

    function setAwake(on) {
        awake = awake.filter(k => k !== currentKey).concat(on ? [currentKey] : []);
        store();
    }

    function store() {
        storage.setText(JSON.stringify({
            layouts: layouts,
            awake: awake
        }));
    }

    // From the panel: applied now, saved if kept.
    function tryLayout(specs) {
        previous = outputs.map(specOf);
        pending = specs;
        apply(specs, false);
        remaining = 15;
        countdown.restart();
    }

    function keep() {
        if (pending === null)
            return;
        save(pending);
        previous = null;
        pending = null;
        countdown.stop();
    }

    // All of them: the outputs may not have caught up with the layout yet.
    function revert() {
        if (previous === null)
            return;
        const specs = previous;
        previous = null;
        pending = null;
        countdown.stop();
        apply(specs, true);
    }

    function refresh() {
        debounce.restart();
    }

    function settle() {
        if (!lidRead)
            return;
        const closed = lidClosed && outputs.some(internal) && docked();
        if (closed !== clamshell) {
            // The other monitors gone with the lid still closed.
            if (clamshell && lidClosed) {
                if (!grace.running) {
                    console.info("Monitors: no other monitor left, clamshell ends in 3 s");
                    grace.start();
                }
                return;
            }
            clamshell = closed;
        }
        grace.stop();
        const changed = currentKey !== appliedKey;
        if (!changed && !reloaded)
            return;
        // Set while the bar ran, rather than found as it started.
        const fresh = changed && appliedKey !== "";
        if (changed && pending !== null) {
            previous = null;
            pending = null;
            countdown.stop();
        }
        appliedKey = currentKey;
        reloaded = false;
        console.info(`Monitors: ${present.map(describe).join(", ")}${saved ? "" : ", no layout saved"}`);
        const specs = saved ? resolve(layouts[currentKey]) : [];
        // Beyond the layout: the laptop's panel, off in clamshell and on again
        // after it, and whatever mirrors the panel while it is off.
        for (const o of outputs.filter(o => !specs.some(s => s.output === o.name))) {
            const s = specOf(o);
            if (internal(o) && clamshell)
                specs.push(Object.assign(s, {
                    disabled: true,
                    mirror: ""
                }));
            else if (internal(o) && o.disabled)
                specs.push(Object.assign(spec(o.name, "preferred", 0, 0, "auto", 0, false, ""), {
                    position: "auto"
                }));
            else if (clamshell && s.mirror !== "" && internal(outputs.find(m => m.name === s.mirror)))
                specs.push(Object.assign(s, {
                    mirror: ""
                }));
        }
        apply(specs, false);
        if (!saved && fresh && present.length > 1)
            notifier.running = true;
    }

    // In the bar's journal, with the layouts applied and any Hyprland rejects,
    // to trace a lid or monitor change after the fact.
    onLidClosedChanged: console.info(`Monitors: lid ${lidClosed ? "closed" : "open"}`)
    onClamshellChanged: console.info(`Monitors: clamshell ${clamshell ? "on" : "off"}`)

    Component.onCompleted: {
        try {
            const state = JSON.parse(storage.text());
            layouts = state.layouts ?? {};
            awake = state.awake ?? [];
        } catch (e) {}
        lidReader.running = true;
    }

    FileView {
        id: storage

        path: Quickshell.statePath("monitors.json")
        blockAllReads: true
        printErrors: false
    }

    // Hyprland reports scale and mode changes not at all, and others one
    // event per monitor.
    Timer {
        id: debounce

        interval: 300
        onTriggered: lister.running = true
    }

    Process {
        id: lister

        command: [Programs.hyprctl, "-j", "monitors", "all"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    // Without FALLBACK, Hyprland's stand-in while no monitor
                    // is on, which no layout covers.
                    root.outputs = JSON.parse(text).filter(o => o.name !== "FALLBACK");
                } catch (e) {
                    return;
                }
                if (root.cursor)
                    root.follow();
                root.settle();
            }
        }
    }

    Process {
        id: locator

        command: [Programs.hyprctl, "-j", "cursorpos"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const p = JSON.parse(text);
                    const output = root.outputs.find(o => {
                        const r = root.rectOf(o);
                        return root.placed(o) && p.x >= r.x && p.x < r.x + r.width && p.y >= r.y && p.y < r.y + r.height;
                    });
                    const r = output ? root.rectOf(output) : null;
                    root.cursor = output ? {
                        name: output.name,
                        rect: r,
                        fx: (p.x - r.x) / r.width,
                        fy: (p.y - r.y) / r.height,
                        tries: 0
                    } : null;
                } catch (e) {
                    root.cursor = null;
                }
                console.info(`Monitors: applying ${root.chunk}`);
                evaluator.running = true;
                root.refresh();
            }
        }
    }

    Process {
        id: evaluator

        command: [Programs.hyprctl, "eval", root.chunk]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() !== "ok")
                console.warn(`Monitors: Hyprland rejected the layout: ${text.trim()}`)
        }
    }

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "configreloaded") {
                root.reloaded = true;
                root.refresh();
            } else if (event.name === "monitoradded" || event.name === "monitorremoved")
                root.refresh();
        }
    }

    Timer {
        id: grace

        interval: 3000
        onTriggered: {
            root.clamshell = false;
            root.refresh();
        }
    }

    // logind's lid as the bar starts, then each change.
    Process {
        id: lidReader

        command: [Programs.gdbus, "call", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1", "--method", "org.freedesktop.DBus.Properties.Get", "org.freedesktop.login1.Manager", "LidClosed"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.lidClosed = text.includes("true");
                root.lidRead = true;
                root.refresh();
            }
        }
    }

    Process {
        running: true
        command: [Programs.gdbus, "monitor", "--system", "--dest", "org.freedesktop.login1", "--object-path", "/org/freedesktop/login1"]
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/'LidClosed': <(true|false)>/);
                if (!m)
                    return;
                root.lidClosed = m[1] === "true";
                root.refresh();
            }
        }
    }

    Process {
        running: root.lidClosed && root.outputs.some(o => root.internal(o) && o.disabled)
        command: [Programs.systemdInhibit, "--what=handle-lid-switch", "--who=Quickshell", "--why=The laptop's panel is off", "--mode=block", Programs.sleep, "infinity"]
        onRunningChanged: console.info(`Monitors: lid switch ${running ? "held" : "released"}`)
    }

    Process {
        running: root.stayAwake
        command: [Programs.systemdInhibit, "--what=idle", "--who=Quickshell", "--why=Stay awake on these displays", "--mode=block", Programs.sleep, "infinity"]
        onRunningChanged: console.info(`Monitors: stay awake ${running ? "on" : "off"}`)
    }

    Timer {
        id: countdown

        interval: 1000
        repeat: true
        onTriggered: {
            root.remaining -= 1;
            if (root.remaining <= 0)
                root.revert();
        }
    }

    Process {
        id: notifier

        command: [Programs.notifySend, "--app-name=Displays", "--icon=preferences-desktop-display", "--action=default=Arrange", "New display arrangement", "No layout is saved for these displays."]
        stdout: StdioCollector {
            onStreamFinished: if (text.trim() === "default")
                root.toggleRequested()
        }
    }

    IpcHandler {
        target: "monitors"

        function toggle(): void {
            root.toggleRequested();
        }
    }
}
