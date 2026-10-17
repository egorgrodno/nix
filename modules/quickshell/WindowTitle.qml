import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Hyprland

// The last focused window of the workspace on this screen, as Waybar's
// `separate-outputs` shows it. Hyprland reports that title only per workspace,
// so the workspaces are re-read on every event that can change it.
Item {
    id: root

    required property HyprlandMonitor monitor
    // Room the bar leaves it; the title shrinks before the other modules do.
    property real maxWidth
    readonly property string title: monitor?.activeWorkspace?.lastIpcObject?.lastwindowtitle ?? ""
    readonly property string text: "   " + title

    visible: title !== ""
    implicitWidth: 16 + label.width + 16
    implicitHeight: parent.height

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (["activewindowv2", "windowtitlev2", "closewindow", "openwindow", "movewindowv2", "workspacev2", "focusedmonv2"].includes(event.name))
                refresh.restart();
        }
    }

    Timer {
        id: refresh

        interval: 20
        onTriggered: Hyprland.refreshWorkspaces()
    }

    // GTK's `max-width-chars`, in its unit: the wider of a sample sentence's
    // mean character and the widest digit. The font's own average is no use,
    // as the Nerd Font icons inflate it.
    FontMetrics {
        id: metrics

        readonly property real charWidth: {
            // Method calls bind to nothing, so this read makes it follow the font.
            font;
            return Math.max(advanceWidth("The quick brown fox jumps over the lazy dog.") / 44, ...[..."0123456789"].map(d => advanceWidth(d)));
        }

        font: label.font
    }

    BarText {
        id: label

        x: 16
        anchors.verticalCenter: parent.verticalCenter
        width: Math.max(0, Math.min(implicitWidth, 50 * metrics.charWidth, root.maxWidth - 32))
        text: root.text
        elide: Text.ElideRight
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: Qt.rgba(0, 0, 0, 0.7)
            shadowVerticalOffset: 1
            shadowHorizontalOffset: 0
            shadowBlur: 0.25
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        onPressed: tip.dismiss()
    }

    // Hangs from the text rather than the module, as Waybar's does.
    Tooltip {
        id: tip

        target: label
        text: root.text
        hovered: mouse.containsMouse
        pointerX: mouse.mouseX - label.x
    }
}
