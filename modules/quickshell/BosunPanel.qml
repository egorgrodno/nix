import QtQuick

// Under the bosun module, 1400×880 cut to the work area, the monitor less
// the outer gaps and both bars, as `fitWorkArea` in modules/desktop cuts
// windows. Expanded, it fills the work area.
Panel {
    id: panel

    readonly property int areaWidth: (screen?.width ?? 1400) - 2 * Theme.outerGap
    readonly property int areaHeight: (screen?.height ?? 880) - 2 * (Theme.barHeight + Theme.outerGap)

    onEnteredChanged: Bosun.panelEntered = entered
    Component.onCompleted: Bosun.panelEntered = false
    Component.onDestruction: Bosun.panelEntered = true

    boxWidth: view.expanded ? areaWidth : Math.min(1400, areaWidth)
    padding: 0
    // The surface spans the screen from the start, so expanding never resizes
    // it.
    margins.left: 0
    implicitWidth: screen?.width ?? 0

    BosunView {
        id: view

        width: panel.contentWidth
        height: view.expanded ? panel.areaHeight : Math.min(880, panel.areaHeight)
    }
}
