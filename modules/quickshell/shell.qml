//@ pragma UseQApplication

import QtQuick
import Quickshell
import Quickshell.Hyprland

ShellRoot {
    Variants {
        model: Quickshell.screens

        Bar {}
    }

    Variants {
        model: Quickshell.screens

        BottomBar {}
    }

    // Once for the shell, not per screen.
    PowerSaverDim {}

    // Over every screen, once for the Hyprland instance.
    Curtain {}

    Lock {}

    SharedLayouts {
        writes: true
    }

    // On the focused screen, which they follow.
    NotificationPopups {}

    Osd {}

    // On the screen focused as it opens, under the top bar. One whose screen
    // goes, as when the layout it tries turns that screen off, opens again on
    // the focused one with the same monitor picked, so the layout can still be
    // kept.
    LazyLoader {
        id: monitors

        property ShellScreen screen
        property string selected

        function open() {
            screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
            active = true;
        }

        MonitorPanel {
            screen: monitors.screen
            selectedName: monitors.selected
            onSelectedNameChanged: monitors.selected = selectedName
            onDismissed: monitors.active = false
        }
    }

    Connections {
        target: Monitors

        function onToggleRequested() {
            if (monitors.active)
                monitors.item.close();
            else {
                monitors.selected = "";
                monitors.open();
            }
        }
    }

    // On the screen focused as it opens, over the bottom bar.
    LazyLoader {
        id: wallpapers

        property ShellScreen screen

        AppearancePanel {
            screen: wallpapers.screen
            onDismissed: wallpapers.active = false
        }
    }

    Connections {
        target: Wallpapers

        function onToggleRequested() {
            if (wallpapers.active)
                wallpapers.item.close();
            else {
                wallpapers.screen = Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0];
                wallpapers.active = true;
            }
        }
    }

    Connections {
        target: Quickshell

        function onScreensChanged() {
            if (monitors.active && !Quickshell.screens.includes(monitors.screen)) {
                monitors.active = false;
                monitors.open();
            }
            if (wallpapers.active && !Quickshell.screens.includes(wallpapers.screen))
                wallpapers.item.close();
        }
    }

    // Reloads report as notifications rather than through Quickshell's own
    // popup, once they settle: an activation swaps the files one at a time, so
    // the reloads it sets off can fail before the last one succeeds.
    Connections {
        target: Quickshell

        function onReloadCompleted() {
            Quickshell.inhibitReloadPopup();
            notice.post("low", "Quickshell reloaded", "");
        }

        function onReloadFailed(error) {
            Quickshell.inhibitReloadPopup();
            notice.post("critical", "Quickshell failed to reload", error);
        }
    }

    Timer {
        id: notice

        property var args: []

        function post(urgency, summary, body) {
            args = [`--urgency=${urgency}`, summary, body];
            restart();
        }

        interval: 1000
        // The tag makes a later notice replace an earlier one.
        onTriggered: Quickshell.execDetached([Programs.notifySend, "--app-name=Quickshell", "--transient", "--hint=string:x-dunst-stack-tag:quickshell"].concat(args))
    }
}
