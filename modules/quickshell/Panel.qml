import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

// A panel opened from a bar module: against the bar, centred on the module
// unless that would cross the outer gap. A layer surface rather than a popup,
// since Hyprland drops a popup's grab whenever another layer surface unmaps, as
// an expiring notification does. A click outside closes it, through Hyprland's
// focus grab, as Escape does. It slides out of the bar as it fades in, and
// back, and eases to a new height when its content changes. On `overlay`,
// above the notification popups, which it holds while it is open.
PanelWindow {
    id: panel

    required property Item module
    default property alias content: column.data
    readonly property alias contentWidth: column.width
    readonly property PanelWindow bar: module.QsWindow.window
    readonly property bool upward: bar?.anchors.bottom === true && bar?.anchors.top !== true
    // False from the start of the close.
    property bool open: false
    // True from just after the first layout, from when height changes ease:
    // content that arrives as the panel opens, as scanned networks do, grows
    // it smoothly rather than in a jump.
    property bool settled: false

    // The close has finished: the owner drops the panel.
    signal dismissed

    function close() {
        open = false;
        grab.active = false;
    }

    screen: bar?.screen ?? null
    anchors {
        left: true
        top: !upward
        bottom: upward
    }
    // The window reaches over the bar as far as the box slides, so the box moves
    // unclipped, and takes input only within the box.
    margins {
        top: Theme.barHeight + 4 - Theme.slide
        bottom: Theme.barHeight + 4 - Theme.slide
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 360
    implicitHeight: box.height + Theme.slide
    color: "transparent"
    focusable: true
    mask: Region {
        item: box
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-panel"

    // Placed once: a module that changes width while the panel is open would
    // otherwise drag it along.
    Component.onCompleted: {
        const x = module.mapToItem(null, 0, 0).x;
        margins.left = Math.max(Theme.outerGap, Math.min(x + (module.width - implicitWidth) / 2, bar.width - Theme.outerGap - implicitWidth));
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

    Rectangle {
        id: box

        width: parent.width
        height: column.implicitHeight + 2 * 20
        // At rest at the window's end away from the bar, starting at the bar's.
        y: panel.upward ? (panel.open ? 0 : Theme.slide) : (panel.open ? Theme.slide : 0)
        opacity: panel.open ? 1 : 0
        color: Theme.alpha(Theme.backgroundMain, 0.97)
        border.color: Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        radius: Theme.radius
        clip: true
        focus: true
        Keys.onEscapePressed: panel.close()
        onOpacityChanged: if (!panel.open && opacity === 0)
            panel.dismissed()

        // One curve both ways: a Behavior starts before the animation's own
        // bindings see `open` change, so a curve bound to it takes the previous
        // transition's.
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

            x: 20
            y: 20
            width: parent.width - 40
            spacing: 20
        }
    }
}
