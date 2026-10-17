import QtQuick
import Quickshell
import Quickshell.Services.Notifications

// A bell and how many notifications arrived since the panel last opened, red
// while one of them is critical; a crossed-out bell in blue under
// do-not-disturb. Click opens the notification panel, right-click toggles
// do-not-disturb.
Pill {
    id: bell

    readonly property int count: Notifications.unseen.length
    readonly property bool critical: Notifications.unseen.some(e => e.urgency === NotificationUrgency.Critical)

    function toggle() {
        if (panel.active)
            panel.item.close();
        else
            panel.active = true;
    }

    lit: panel.active
    tooltip: [count === 0 ? "No new notifications" : count === 1 ? "1 new notification" : `${count} new notifications`].concat(Notifications.dnd ? ["Do not disturb"] : []).join("\n")
    onClicked: button => {
        if (button === Qt.LeftButton)
            toggle();
        else if (button === Qt.RightButton)
            Notifications.dnd = !Notifications.dnd;
    }

    // The bind's toggle, for the bell on the focused screen.
    Connections {
        target: Notifications

        function onToggleRequested() {
            if (bell.QsWindow.window?.screen === Notifications.screen)
                bell.toggle();
        }
    }

    // A slot as wide as the wider glyph, measured as on the volume module.
    BarText {
        id: glyphs

        visible: false
        text: "\u{F009A}\n\u{F009B}"
    }

    BarText {
        anchors.verticalCenter: parent.verticalCenter
        width: glyphs.implicitWidth
        horizontalAlignment: Text.AlignHCenter
        text: Notifications.dnd ? "\u{F009B}" : "\u{F009A}"
        color: Notifications.dnd ? Theme.blue : "#ffffff"
    }

    Figure {
        anchors.verticalCenter: parent.verticalCenter
        widest: "99"
        text: `${Math.min(bell.count, 99)}`
        color: bell.critical ? Theme.red : bell.count > 0 ? "#ffffff" : Theme.foregroundDark
    }

    LazyLoader {
        id: panel

        NotificationPanel {
            module: bell
            onDismissed: panel.active = false
        }
    }
}
