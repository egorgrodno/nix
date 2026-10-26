import QtQuick

// Under the bosun module, 1400×880 cut to the work area, the monitor less
// the outer gaps and both bars, as `fitWorkArea` in modules/desktop cuts
// windows.
Panel {
    id: panel

    boxWidth: Math.min(1400, (screen?.width ?? 1400) - 2 * Theme.outerGap)
    padding: 0

    BosunView {
        width: panel.contentWidth
        height: Math.min(880, (panel.screen?.height ?? 880) - 2 * (Theme.barHeight + Theme.outerGap))
    }
}
