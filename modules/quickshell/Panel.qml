import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// A panel opened from a bar module: against the bar, centred on the module
// unless that would cross the outer gap, or, opened without one, centred on
// its screen under the top bar, or over the bottom one if `upward`. A layer
// surface rather than a popup, since Hyprland drops a popup's grab whenever
// another layer surface unmaps, as an expiring notification does. A click
// outside closes it, through Hyprland's focus grab, as Escape does. It slides
// out of the bar as it fades in, and back, and eases to a new height when its
// content changes, casting a shadow over the windows. On `overlay`, above the
// notification popups, which it holds while it is open.
PanelWindow {
    id: panel

    // Null for a panel whose owner sets its screen.
    property Item module: null
    property int boxWidth: 360
    // The box's left edge on screen. The surface reaches past it on both sides
    // for the shadow, within the screen.
    property real boxX: 0
    default property alias content: column.data
    readonly property alias contentWidth: column.width
    readonly property PanelWindow bar: module?.QsWindow.window ?? null
    // A module's bar decides, else the owner.
    property bool upward: bar?.anchors.bottom === true && bar?.anchors.top !== true
    // False from the start of the close.
    property bool open: false
    // True from just after the first layout, from when height changes ease:
    // content that arrives as the panel opens, as scanned networks do, grows
    // it smoothly rather than in a jump.
    property bool settled: false
    // Between the box's edge and the content.
    property int padding: 20

    // The close has finished: the owner drops the panel.
    signal dismissed

    function close() {
        open = false;
        grab.active = false;
    }

    // Hyprland hands the keyboard to the focused window whenever another layer
    // surface unmaps, as the OSD does, grab or not; a new grab takes it back.
    // Only the newest panel does, so two open never trade it.
    function retake() {
        if (!open || Notifications.panels[Notifications.panels.length - 1] !== panel)
            return;
        grab.active = false;
        grab.active = true;
    }

    screen: bar?.screen ?? null
    // The strip between the bars, reaching over each as far as the box slides,
    // so the box moves unclipped and the surface never resizes: Hyprland draws
    // a resize in flight by stretching the last frame. Input is taken only
    // within the box.
    anchors {
        left: true
        top: true
        bottom: true
    }
    margins {
        left: Math.max(0, boxX - Theme.shadow)
        top: Theme.barHeight + 4 - Theme.slide
        bottom: Theme.barHeight + 4 - Theme.slide
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: Math.min(screen?.width ?? Infinity, boxX + boxWidth + Theme.shadow) - margins.left
    color: "transparent"
    focusable: true
    mask: Region {
        item: box
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-panel"

    // Placed once against a module: one that changes width while the panel is
    // open would otherwise drag it along. Without one it stays centred as the
    // screen changes size, as it does under the monitor panel's own changes.
    Component.onCompleted: {
        if (module) {
            const x = module.mapToItem(null, 0, 0).x;
            boxX = Math.max(Theme.outerGap, Math.min(x + (module.width - boxWidth) / 2, bar.width - Theme.outerGap - boxWidth));
        } else
            boxX = Qt.binding(() => Math.max(0, (screen?.width ?? boxWidth) - boxWidth) / 2);
        open = true;
        Qt.callLater(() => settled = true);
        Notifications.panels = [...Notifications.panels, panel];
    }

    Component.onDestruction: Notifications.panels = Notifications.panels.filter(p => p !== panel)

    HyprlandFocusGrab {
        id: grab

        active: true
        windows: [panel]
        onCleared: panel.close()
    }

    // Where the box rests, against the bar with the gap between, its edge on
    // the bar's side fixed as the box eases to a new height. As wide as the
    // panel asks rather than as the window is, whose width passes through 0
    // as the surface is configured, which would wrap the content tall.
    Item {
        x: panel.boxX - panel.margins.left
        width: panel.boxWidth
        height: box.height
        y: panel.upward ? parent.height - Theme.slide - height : Theme.slide

        Shadow {
            target: box
        }

        Rectangle {
            id: box

            readonly property bool windowActive: Window.active

            width: parent.width
            height: column.implicitHeight + 2 * panel.padding
            // Starting under the bar's edge.
            y: panel.open ? 0 : panel.upward ? Theme.slide : -Theme.slide
            opacity: panel.open ? 1 : 0
            color: Theme.alpha(Theme.backgroundMain, 0.97)
            border.color: Qt.rgba(1, 1, 1, 0.08)
            border.width: 1
            radius: Theme.radius
            clip: true
            focus: true
            Keys.onEscapePressed: panel.close()
            onWindowActiveChanged: if (!windowActive)
                Qt.callLater(panel.retake)
            onOpacityChanged: if (!panel.open && opacity === 0)
                panel.dismissed()

            // One curve both ways: a Behavior starts before the animation's own
            // bindings see `open` change, so a curve bound to it takes the
            // previous transition's.
            Behavior on y {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutExpo
                }
            }

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutExpo
                }
            }

            Behavior on height {
                enabled: panel.settled

                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutExpo
                }
            }

            Column {
                id: column

                x: panel.padding
                y: panel.padding
                width: parent.width - 2 * panel.padding
                spacing: 20
            }
        }
    }
}
