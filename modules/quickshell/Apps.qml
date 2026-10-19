import QtQuick
import Quickshell
import Quickshell.Hyprland

// Click opens the launcher on its apps, as the binds open it in their modes on
// the focused screen. A bind for the mode already showing closes it, and one
// for another switches to it.
Pill {
    id: apps

    function toggle(mode) {
        if (!panel.active) {
            panel.mode = mode;
            panel.active = true;
        } else if (panel.item.open && panel.item.mode !== mode)
            panel.item.mode = mode;
        else
            panel.item.close();
    }

    text: "\u{F003B}"
    lit: panel.active
    onClicked: button => {
        if (button === Qt.LeftButton)
            toggle("apps");
    }

    Connections {
        target: Launcher

        function onToggleRequested(mode) {
            if (apps.QsWindow.window?.screen?.name === Hyprland.focusedMonitor?.name)
                apps.toggle(mode);
        }
    }

    LazyLoader {
        id: panel

        property string mode

        LauncherPanel {
            module: apps
            mode: panel.mode
            onDismissed: panel.active = false
        }
    }
}
