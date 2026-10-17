import QtQuick
import Quickshell.Hyprland

// The active submap's name; hidden in the default one.
Pill {
    id: submap

    property string name

    visible: name !== ""
    hoverable: false
    text: name
    textColor: Theme.yellow
    tooltip: name

    Connections {
        target: Hyprland

        function onRawEvent(event) {
            if (event.name === "submap")
                submap.name = event.data;
        }
    }
}
