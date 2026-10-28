import QtQuick

// Under the bosun module, at the size used last. The full panel fills the
// work area, the monitor less the outer gaps and both bars, as `fitWorkArea`
// in modules/desktop cuts windows, grown by Hyprland's window border with the
// window's corners, so the focused window's border, drawn outside it, never
// shows around the panel. The overview is a dropdown under the module.
Panel {
    id: panel

    readonly property bool full: BosunKept.full
    readonly property int areaWidth: (screen?.width ?? 1400) - 2 * Theme.outerGap
    readonly property int areaHeight: (screen?.height ?? 880) - 2 * (Theme.barHeight + Theme.outerGap)
    // The BosunView or the BosunOverview.
    readonly property var shown: loader.item

    // A composer takes the keyboard back as `panelEntered` changes, so a
    // record none claims then goes, never to take it from the user later.
    onEnteredChanged: {
        Bosun.panelEntered = entered;
        if (entered)
            BosunKept.typing = null;
    }
    Component.onCompleted: {
        Bosun.panelEntered = false;
        Bosun.panels = [...Bosun.panels, panel];
    }
    onOpenChanged: if (!open)
        keepField()
    Component.onDestruction: {
        Bosun.panels = Bosun.panels.filter(p => p !== panel);
        Bosun.panelEntered = true;
        BosunKept.save();
    }

    boxWidth: full ? areaWidth + 2 * grow : 440
    grow: full ? Theme.borderSize : 0
    boxRadius: full ? Theme.rounding + grow : Theme.radius
    padding: 0
    // The surface spans the screen from the start, so a change of size never
    // resizes it.
    margins.left: 0
    implicitWidth: screen?.width ?? 0

    // The composer with the keyboard, for BosunComposer to take it back when
    // the panel opens again.
    function keepField() {
        let item = loader.Window.activeFocusItem;
        while (item && item.draftKey === undefined)
            item = item.parent;
        BosunKept.typing = item ? {
            key: item.draftKey,
            cursor: item.cursor
        } : null;
    }

    // What Bosun's IpcHandler asks of the panel for a script, each returning
    // "" when done, else why it did nothing, as the view shown answers. A
    // row's opens the full panel on it, from the overview too, as a click
    // does.

    function setMode(name) {
        if (!["full", "overview"].includes(name))
            return `no mode ${name}`;
        BosunKept.full = name === "full";
        return "";
    }

    function setSidebar(how) {
        return shown.setSidebar(how);
    }

    function selectRow(key) {
        BosunKept.full = true;
        return shown.selectRow(key);
    }

    function focusAt(where) {
        return shown.focusAt(where);
    }

    function armAction(action) {
        return shown.armAction(action);
    }

    function panelState() {
        return Object.assign({
            entered: entered
        }, shown?.panelState() ?? {});
    }

    // The box at rest in the compositor's layout, where a screenshot crops.
    function geometry() {
        return {
            screen: {
                name: screen?.name ?? "",
                x: screen?.x ?? 0,
                y: screen?.y ?? 0
            },
            x: Math.round((screen?.x ?? 0) + boxRect.x),
            y: Math.round((screen?.y ?? 0) + boxRect.y),
            width: Math.round(boxRect.width),
            height: Math.round(boxRect.height)
        };
    }

    Loader {
        id: loader

        width: panel.contentWidth
        sourceComponent: panel.full ? fullView : overview
    }

    Component {
        id: fullView

        BosunView {
            height: panel.areaHeight + 2 * panel.grow
        }
    }

    Component {
        id: overview

        BosunOverview {
            maxHeight: panel.areaHeight
        }
    }
}
