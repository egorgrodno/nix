import QtQuick
import Quickshell
import Quickshell.Hyprland

// Todoist's tasks due today and overdue, counted, the mark red while any is
// overdue; hidden without a token. A click opens the Todoist panel, as the bind
// does on the focused screen.
Pill {
    id: tasks

    function toggle() {
        if (panel.active)
            panel.item.close();
        else
            panel.active = true;
    }

    visible: Todoist.enabled
    lit: panel.active
    tooltip: Todoist.error || `${Todoist.overdue.length} overdue, ${Todoist.dueCount - Todoist.overdue.length} due today`
    onClicked: button => {
        if (button === Qt.LeftButton)
            toggle();
    }

    BarText {
        anchors.verticalCenter: parent.verticalCenter
        text: "\u{F0134}"
        color: Todoist.overdue.length > 0 ? Theme.red : Theme.foregroundStrong
        font.pixelSize: 18
    }

    Figure {
        anchors.verticalCenter: parent.verticalCenter
        text: Todoist.dueCount
    }

    Connections {
        target: Todoist

        function onToggleRequested() {
            if (tasks.QsWindow.window?.screen?.name === Hyprland.focusedMonitor?.name)
                tasks.toggle();
        }
    }

    LazyLoader {
        id: panel

        TodoistPanel {
            module: tasks
            onDismissed: panel.active = false
        }
    }
}
