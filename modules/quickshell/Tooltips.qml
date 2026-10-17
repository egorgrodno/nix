pragma Singleton

import QtQuick
import Quickshell

// GTK's browse mode: once a tooltip has shown, the next one opens almost at
// once, until the pointer has rested off every module for half a second.
Singleton {
    id: root

    property bool browsing: false

    function left() {
        cooldown.restart();
    }

    function shown() {
        cooldown.stop();
        browsing = true;
    }

    Timer {
        id: cooldown

        interval: 500
        onTriggered: root.browsing = false
    }
}
