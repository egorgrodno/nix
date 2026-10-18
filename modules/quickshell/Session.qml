pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The session menu's actions, least drastic first, each on a key: a bare
// letter, or Shift and S to shut down, which Caps Lock alone never sends.
// Hibernate only where the host hibernates, where a suspend also hibernates
// after HibernateDelaySec, as the idle one does.
Singleton {
    id: root

    readonly property var actions: [
        {
            glyph: "\u{F033E}",
            label: "Lock",
            key: Qt.Key_L,
            command: [Programs.loginctl, "lock-session"]
        },
        {
            glyph: "\u{F0904}",
            label: "Suspend",
            key: Qt.Key_U,
            command: [Programs.systemctl, Host.hibernate ? "suspend-then-hibernate" : "suspend"]
        },
        ...(Host.hibernate ? [
                {
                    glyph: "\u{F04B2}",
                    label: "Hibernate",
                    key: Qt.Key_H,
                    command: [Programs.systemctl, "hibernate"]
                }
            ] : []),
        {
            glyph: "\u{F0343}",
            label: "Log out",
            key: Qt.Key_E,
            // terminate-session has no default, and `auto` names the user's
            // graphical session from outside it, as the bar's unit is.
            command: [Programs.loginctl, "terminate-session", "auto"]
        },
        {
            glyph: "\u{F0709}",
            label: "Reboot",
            key: Qt.Key_R,
            command: [Programs.systemctl, "reboot"]
        },
        {
            glyph: "\u{F0425}",
            label: "Shut down",
            key: Qt.Key_S,
            shift: true,
            command: [Programs.systemctl, "poweroff"]
        }
    ]

    // The power module on the focused screen opens or closes its menu.
    signal toggleRequested

    IpcHandler {
        target: "session"

        function toggle(): void {
            root.toggleRequested();
        }
    }
}
