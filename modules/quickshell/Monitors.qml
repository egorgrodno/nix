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
Singleton {
    id: root

    property var outputs: []
    // By set key, a spec per monitor, its output and mirror as descriptions.
    property var layouts: ({})
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
    readonly property string currentKey: key(outputs)
    readonly property bool saved: currentKey in layouts

    signal toggleRequested

    function key(list) {
        return list.map(describe).sort().join("\n");
    }

    // A headless output has no description.
    function describe(output) {
        return output.description || output.name;
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
        const free = [...outputs].sort((a, b) => a.name.localeCompare(b.name));
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
        storage.setText(JSON.stringify({
            layouts: layouts
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
        if (saved)
            apply(resolve(layouts[currentKey]), false);
        else if (fresh && outputs.length > 1)
            notifier.running = true;
    }

    Component.onCompleted: {
        try {
            layouts = JSON.parse(storage.text()).layouts ?? {};
        } catch (e) {}
        refresh();
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
                    root.outputs = JSON.parse(text);
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
                Quickshell.execDetached([Programs.hyprctl, "eval", root.chunk]);
                root.refresh();
            }
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
