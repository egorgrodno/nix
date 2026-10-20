import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

// Click opens the session menu, as the bind does on the focused screen. The
// tooltip gives the time since boot, sleep included, read as the pointer
// arrives.
Pill {
    id: power

    property int uptime: 0

    function toggle() {
        if (panel.active)
            panel.item.close();
        else
            panel.active = true;
    }

    text: "⏻"
    textColor: hovered || lit ? "#ffffff" : Theme.red
    hoverFill: Theme.alpha(Theme.red, 0.5)
    lit: panel.active
    tooltip: {
        const minutes = Math.floor(uptime / 60);
        const days = Math.floor(minutes / 1440);
        const hours = Math.floor(minutes % 1440 / 60);
        return `Up ${days > 0 ? `${days} d ` : ""}${days > 0 || hours > 0 ? `${hours} h ` : ""}${minutes % 60} min`;
    }
    onHoveredChanged: {
        if (hovered) {
            procUptime.reload();
            uptime = parseFloat(procUptime.text());
        }
    }
    onClicked: button => {
        if (button === Qt.LeftButton)
            toggle();
    }

    FileView {
        id: procUptime

        path: "/proc/uptime"
        blockAllReads: true
    }

    Connections {
        target: Session

        function onToggleRequested() {
            if (power.QsWindow.window?.screen?.name === Hyprland.focusedMonitor?.name)
                power.toggle();
        }
    }

    LazyLoader {
        id: panel

        SessionPanel {
            module: power
            onDismissed: panel.active = false
        }
    }
}
