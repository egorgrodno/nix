//@ pragma UseQApplication

import QtQuick
import Quickshell

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

    // On the focused screen, which it follows.
    NotificationPopups {}

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
