import QtQuick
import Quickshell
import Quickshell.Hyprland

// Click opens the session menu, as the bind does on the focused screen.
Pill {
    id: power

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
    onClicked: button => {
        if (button === Qt.LeftButton)
            toggle();
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
