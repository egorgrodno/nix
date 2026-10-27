import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Wayland

// The connected monitors to arrange: each one in use as a box at its logical
// size, dragged into place and snapped edge to edge against the others, and
// for the one selected its resolution, refresh rate, scale, rotation, mirror
// and whether it is on. Apply tries the layout, which reverts after 15 s
// unless kept; a layout kept, or the current one saved, applies whenever these
// monitors connect. Stay awake, also per set of monitors, takes effect at once.
// While it is open each screen shows its name.
Panel {
    id: panel

    // Per output: { name, description, modes, mode, x, y, scale, transform,
    // disabled, mirror }, positions logical.
    property var draft: []
    // Set by an edit, so a refresh of the outputs leaves the draft alone.
    property bool edited: false
    // The monitor picked, kept while it is missing from the outputs for a
    // moment, and by the owner for a panel reopened on another screen. Until
    // one is picked, or while it is missing, the focused one shows.
    property string selectedName: ""
    readonly property var selected: draft.find(m => m.name === selectedName) ?? draft.find(m => m.name === Monitors.outputs.find(o => o.focused)?.name) ?? draft[0] ?? null
    readonly property var placed: inUse(draft)
    readonly property bool dirty: draft.some(m => {
        const output = Monitors.outputs.find(o => o.name === m.name);
        return !output || !Monitors.same(specOf(m), Monitors.specOf(output));
    })
    // The placed boxes' extent, logical.
    readonly property var bounds: {
        const rects = placed.map(rect);
        const left = Math.min(...rects.map(r => r.x));
        const top = Math.min(...rects.map(r => r.y));
        return {
            x: left,
            y: top,
            width: Math.max(...rects.map(r => r.x + r.width)) - left,
            height: Math.max(...rects.map(r => r.y + r.height)) - top
        };
    }

    function load() {
        draft = Monitors.present.map(o => {
            const spec = Monitors.specOf(o);
            const modes = Monitors.modes(o);
            return {
                name: o.name,
                description: Monitors.describe(o),
                modes: modes,
                mode: modes.find(m => m.mode === spec.mode) ?? modes[0],
                x: o.x,
                y: o.y,
                scale: o.scale,
                transform: o.transform,
                disabled: o.disabled,
                mirror: spec.mirror
            };
        });
        edited = false;
    }

    function specOf(m) {
        return Monitors.spec(m.name, m.mode.mode, m.x, m.y, m.scale, m.transform, m.disabled, m.mirror);
    }

    function inUse(list) {
        return list.filter(m => !m.disabled && m.mirror === "");
    }

    // A rotation by a quarter turn either way swaps the sides.
    function rect(m) {
        const turned = m.transform % 2 === 1;
        return {
            x: m.x,
            y: m.y,
            width: Math.round((turned ? m.mode.height : m.mode.width) / m.scale),
            height: Math.round((turned ? m.mode.width : m.mode.height) / m.scale)
        };
    }

    // Where a box of the size nearest (x, y) shares an edge with one of the
    // others, along a fifth of the shorter side at least, overlapping none,
    // aligned with that one's edges or centre when within a tenth of its size.
    function snap(size, x, y, others) {
        if (others.length === 0)
            return {
                x: x,
                y: y
            };
        let best = null;
        const overlaps = (a, b) => a.x < b.x + b.width && b.x < a.x + a.width && a.y < b.y + b.height && b.y < a.y + a.height;
        const align = (v, targets, span) => targets.find(t => Math.abs(v - t) < span / 10) ?? v;
        const consider = (cx, cy) => {
            const r = {
                x: Math.round(cx),
                y: Math.round(cy),
                width: size.width,
                height: size.height
            };
            const distance = Math.hypot(r.x - x, r.y - y);
            if (!others.some(o => overlaps(r, o)) && (!best || distance < best.distance))
                best = Object.assign(r, {
                    distance: distance
                });
        };
        for (const o of others) {
            const ky = Math.round(Math.min(size.height, o.height) / 5);
            const kx = Math.round(Math.min(size.width, o.width) / 5);
            const cy = Math.max(o.y - size.height + ky, Math.min(o.y + o.height - ky, y));
            const cx = Math.max(o.x - size.width + kx, Math.min(o.x + o.width - kx, x));
            const vertical = align(cy, [o.y, o.y + o.height - size.height, o.y + (o.height - size.height) / 2], o.height);
            const horizontal = align(cx, [o.x, o.x + o.width - size.width, o.x + (o.width - size.width) / 2], o.width);
            consider(o.x + o.width, vertical);
            consider(o.x - size.width, vertical);
            consider(horizontal, o.y + o.height);
            consider(horizontal, o.y - size.height);
        }
        return best ?? {
            x: x,
            y: y
        };
    }

    // Each box in use, left to right, against those before it, then the
    // whole moved to start at the origin.
    function pack(list) {
        const done = [];
        for (const m of inUse(list).sort((a, b) => a.x - b.x || a.y - b.y)) {
            const p = snap(rect(m), m.x, m.y, done);
            m.x = p.x;
            m.y = p.y;
            done.push(rect(m));
        }
        const left = Math.min(...done.map(r => r.x));
        const top = Math.min(...done.map(r => r.y));
        for (const m of inUse(list)) {
            m.x -= left;
            m.y -= top;
        }
    }

    // A change to the selected monitor, or to the list, on a copy.
    function edit(change) {
        const list = draft.map(m => Object.assign({}, m));
        change(list.find(m => m.name === selected?.name), list);
        pack(list);
        draft = list;
        edited = true;
    }

    function drop(name, x, y) {
        edit((_, list) => {
            const moved = list.find(m => m.name === name);
            const p = snap(rect(moved), x, y, inUse(list).filter(m => m !== moved).map(rect));
            moved.x = p.x;
            moved.y = p.y;
        });
    }

    // The scales at which the mode is a whole number of logical pixels, which
    // Hyprland quantises to 1/120: d/120 where d divides 120 * gcd(width,
    // height). Up to 3, while the shorter side keeps 600 logical pixels.
    function scales(mode, current) {
        let a = mode.width;
        let b = mode.height;
        while (b) {
            [a, b] = [b, a % b];
        }
        const list = [];
        for (let d = 120; d <= 360; d++)
            if (120 * a % d === 0 && Math.min(mode.width, mode.height) * 120 / d >= 600)
                list.push(d / 120);
        return list.length > 0 ? list : [current];
    }

    function nearest(list, value) {
        return list.reduce((best, v) => Math.abs(v - value) < Math.abs(best - value) ? v : best);
    }

    boxWidth: 600

    Component.onCompleted: {
        load();
        Monitors.refresh();
    }

    Connections {
        target: Monitors

        function onPresentChanged() {
            if (!panel.edited)
                panel.load();
        }
    }

    // Each screen's name, in its lower left corner, clear of the panel.
    Variants {
        model: Quickshell.screens.length > 1 ? Quickshell.screens : []

        PanelWindow {
            required property ShellScreen modelData

            screen: modelData
            anchors {
                bottom: true
                left: true
            }
            margins {
                bottom: Theme.barHeight + 18
                left: Theme.outerGap
            }
            exclusionMode: ExclusionMode.Ignore
            implicitWidth: label.implicitWidth + 48
            implicitHeight: label.implicitHeight + 24
            color: "transparent"
            mask: Region {}
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-identify"

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius
                color: Theme.alpha(Theme.backgroundRaised, 0.94)
                border.width: 1
                border.color: modelData?.name === panel.selected?.name ? Theme.blue : Theme.tint(0.08)

                BarText {
                    id: label

                    anchors.centerIn: parent
                    text: modelData?.name ?? ""
                    font.pixelSize: 28
                }
            }
        }
    }

    // All but the footer, scrolling once taller than the strip between the
    // bars leaves, so Keep stays in reach at any scale. The 20 is the panel's
    // spacing above the footer.
    Flickable {
        readonly property real limit: (panel.screen?.height ?? 800) - 2 * (Theme.barHeight + Theme.outerGap) - 2 * panel.padding - 20 - footer.height

        width: panel.contentWidth
        height: Math.min(contentHeight, limit)
        contentHeight: body.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: OverlayScrollBar {}

        Column {
            id: body

            width: parent.width
            spacing: 20

            BarText {
                text: "Displays"
                font.pixelSize: 18
            }

            // The boxes, fitted and centred, each showing its name and logical
            // size.
            Rectangle {
                id: canvas

                readonly property real factor: Math.min((width - 40) / panel.bounds.width, (height - 40) / panel.bounds.height)
                readonly property real originX: (width - panel.bounds.width * factor) / 2
                readonly property real originY: (height - panel.bounds.height * factor) / 2

                width: panel.contentWidth
                height: 220
                radius: Theme.radius - 4
                color: Theme.tint(0.03)
                border.width: 1
                border.color: Theme.tint(0.06)

                Repeater {
                    model: panel.placed

                    Rectangle {
                        id: box

                        required property var modelData
                        readonly property var logical: panel.rect(modelData)
                        readonly property bool current: modelData.name === panel.selected?.name

                        x: canvas.originX + (modelData.x - panel.bounds.x) * canvas.factor + area.offset.x
                        y: canvas.originY + (modelData.y - panel.bounds.y) * canvas.factor + area.offset.y
                        z: area.pressed ? 1 : 0
                        width: logical.width * canvas.factor
                        height: logical.height * canvas.factor
                        radius: 4
                        color: current ? Theme.alpha(Theme.blue, 0.22) : Theme.tint(0.07)
                        border.width: 1
                        border.color: current ? Theme.blue : Theme.tint(0.2)

                        Column {
                            anchors.centerIn: parent
                            spacing: 2

                            BarText {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: box.modelData.name
                                font.pixelSize: 14
                            }

                            Caption {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: `${box.logical.width}×${box.logical.height}`
                                font.pixelSize: 12
                            }
                        }

                        // Tracked against the canvas, which the box moves over.
                        MouseArea {
                            id: area

                            property point start
                            property point offset

                            anchors.fill: parent
                            preventStealing: true
                            cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                            onPressed: mouse => {
                                start = mapToItem(canvas, mouse.x, mouse.y);
                                panel.selectedName = box.modelData.name;
                            }
                            onPositionChanged: mouse => {
                                const p = mapToItem(canvas, mouse.x, mouse.y);
                                offset = Qt.point(p.x - start.x, p.y - start.y);
                            }
                            onReleased: {
                                if (offset.x !== 0 || offset.y !== 0)
                                    panel.drop(box.modelData.name, box.modelData.x + offset.x / canvas.factor, box.modelData.y + offset.y / canvas.factor);
                                offset = Qt.point(0, 0);
                            }
                        }
                    }
                }
            }

            Item {
                width: panel.contentWidth
                height: Math.max(awakeText.implicitHeight, awakeToggle.height)

                Column {
                    id: awakeText

                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - awakeToggle.width - 12
                    spacing: 2

                    BarText {
                        text: "Stay awake"
                    }

                    Caption {
                        width: parent.width
                        elide: Text.ElideRight
                        text: "No dim, lock or suspend while these displays are connected"
                    }
                }

                Toggle {
                    id: awakeToggle

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    checked: Monitors.stayAwake
                    hovered: awakeMouse.containsMouse
                }

                MouseArea {
                    id: awakeMouse

                    anchors.fill: parent
                    hoverEnabled: true
                    onClicked: Monitors.setAwake(!Monitors.stayAwake)
                }
            }

            // The selected monitor's settings, each a row of choices under its
            // label. A disabled or mirroring monitor, which has no box, is
            // picked here.
            Column {
                width: panel.contentWidth
                visible: panel.selected !== null
                spacing: 14

                Choices {
                    label: "Monitor"
                    visible: panel.draft.length > 1
                    values: panel.draft.map(m => m.name)
                    chosen: name => name === panel.selected?.name
                    onPicked: value => panel.selectedName = value
                }

                Item {
                    width: parent.width
                    height: Math.max(heading.implicitHeight, power.height)

                    Column {
                        id: heading

                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width - power.width - 12
                        spacing: 2

                        BarText {
                            text: panel.selected?.name ?? ""
                        }

                        Caption {
                            width: parent.width
                            elide: Text.ElideRight
                            text: panel.selected?.description ?? ""
                        }
                    }

                    // The last monitor in use stays on.
                    Toggle {
                        id: power

                        readonly property bool last: panel.placed.length === 1 && panel.placed[0] === panel.selected

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        opacity: last ? 0.4 : 1
                        checked: !(panel.selected?.disabled ?? true)
                        hovered: powerMouse.containsMouse

                        MouseArea {
                            id: powerMouse

                            anchors.fill: parent
                            enabled: !power.last
                            hoverEnabled: true
                            onClicked: panel.edit(m => m.disabled = !m.disabled)
                        }
                    }
                }

                Choices {
                    label: "Resolution"
                    visible: !(panel.selected?.disabled ?? true)
                    values: {
                        const seen = new Set();
                        return (panel.selected?.modes ?? []).filter(m => {
                            const size = `${m.width}x${m.height}`;
                            return !seen.has(size) && seen.add(size);
                        }).sort((a, b) => b.width * b.height - a.width * a.height);
                    }
                    text: m => `${m.width}×${m.height}`
                    chosen: m => m.width === panel.selected?.mode.width && m.height === panel.selected?.mode.height
                    onPicked: value => panel.edit(m => {
                            m.mode = m.modes.filter(o => o.width === value.width && o.height === value.height).sort((a, b) => b.rate - a.rate)[0];
                            const valid = panel.scales(m.mode, m.scale);
                            if (!valid.some(s => Math.abs(s - m.scale) < 0.001))
                                m.scale = panel.nearest(valid, m.scale);
                        })
                }

                Choices {
                    label: "Refresh rate"
                    visible: !(panel.selected?.disabled ?? true)
                    values: (panel.selected?.modes ?? []).filter(m => m.width === panel.selected.mode.width && m.height === panel.selected.mode.height)
                    text: m => `${Math.round(m.rate * 100) / 100} Hz`
                    chosen: m => m.mode === panel.selected?.mode.mode
                    onPicked: value => panel.edit(m => m.mode = value)
                }

                Choices {
                    label: "Scale"
                    visible: !(panel.selected?.disabled ?? true)
                    values: panel.selected ? panel.scales(panel.selected.mode, panel.selected.scale) : []
                    text: s => s.toFixed(2)
                    chosen: s => Math.abs(s - (panel.selected?.scale ?? 0)) < 0.001
                    onPicked: value => panel.edit(m => m.scale = value)
                }

                Choices {
                    label: "Rotation"
                    visible: !(panel.selected?.disabled ?? true)
                    values: [0, 1, 2, 3]
                    text: t => `${t * 90}°`
                    chosen: t => t === panel.selected?.transform
                    onPicked: value => panel.edit(m => m.transform = value)
                }

                Choices {
                    label: "Mirror"
                    visible: !(panel.selected?.disabled ?? true) && panel.draft.length > 1
                    values: ["", ...panel.draft.filter(m => m.name !== panel.selected?.name && !m.disabled && m.mirror === "").map(m => m.name)]
                    text: name => name === "" ? "None" : name
                    chosen: name => name === panel.selected?.mirror
                    onPicked: value => panel.edit(m => m.mirror = value)
                }
            }
        }
    }

    // Whether the layout is saved, then what can be done with it.
    Item {
        id: footer

        width: panel.contentWidth
        height: 28

        Caption {
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (Monitors.pending)
                    return `Keep this layout? Reverting in ${Monitors.remaining} s`;
                return Monitors.saved ? "Saved for these displays" : "No layout saved for these displays";
            }
            color: Monitors.pending ? Theme.yellow : Theme.foregroundMuted
        }

        Row {
            anchors.right: parent.right
            spacing: 8

            TextButton {
                visible: Monitors.pending !== null
                text: "Revert"
                onClicked: Monitors.revert()
            }

            TextButton {
                visible: Monitors.pending !== null
                text: "Keep"
                lit: true
                hoverFill: Theme.blue
                textColor: Theme.backgroundMain
                onClicked: Monitors.keep()
            }

            TextButton {
                visible: Monitors.pending === null && panel.dirty
                text: "Reset"
                onClicked: panel.load()
            }

            TextButton {
                visible: Monitors.pending === null && (panel.dirty || !Monitors.saved)
                text: panel.dirty ? "Apply" : "Save"
                onClicked: {
                    const specs = panel.draft.map(panel.specOf);
                    if (panel.dirty) {
                        Monitors.tryLayout(specs);
                        panel.edited = false;
                    } else
                        Monitors.save(specs);
                }
            }
        }
    }

    // A label, then the choices as buttons, wrapping, the chosen one lit.
    component Choices: Column {
        id: choices

        property alias label: caption.text
        property var values: []
        property var text: v => String(v)
        property var chosen: v => false

        signal picked(var value)

        width: parent.width
        spacing: 6

        Caption {
            id: caption
        }

        Flow {
            width: parent.width
            spacing: 6

            Repeater {
                model: choices.values

                TextButton {
                    required property var modelData

                    text: choices.text(modelData)
                    lit: choices.chosen(modelData)
                    hoverFill: lit ? Theme.blue : Theme.tint(0.12)
                    textColor: lit ? Theme.backgroundMain : Theme.foregroundStrong
                    onClicked: choices.picked(modelData)
                }
            }
        }
    }
}
