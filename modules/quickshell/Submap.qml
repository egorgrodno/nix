import QtQuick
import Quickshell.Hyprland

// The active submap's name, which slides out from under the workspaces as it
// fades in, and back on returning to the default submap.
Item {
    id: submap

    property bool active
    // Kept while it slides back.
    property string name

    width: active ? pill.implicitWidth : 0
    height: parent.height
    visible: width > 0
    clip: true

    // One curve both ways, as in Panel.qml.
    Behavior on width {
        NumberAnimation {
            duration: 200
            easing.type: Easing.OutExpo
        }
    }

    Pill {
        id: pill

        anchors.right: parent.right
        opacity: submap.active ? 1 : 0
        hoverable: false
        text: submap.name
        textColor: Theme.yellow
        tooltip: submap.name

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutExpo
            }
        }
    }

    Connections {
        target: Hyprland

        // The name first, so the width animates to its final value.
        function onRawEvent(event) {
            if (event.name !== "submap")
                return;
            if (event.data !== "")
                submap.name = event.data;
            submap.active = event.data !== "";
        }
    }
}
