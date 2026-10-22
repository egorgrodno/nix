import QtQuick
import Quickshell

// Polls while the window it sits in shows, as a tooltip's content does: at
// once, half a second on, so a rate has its first figure, then every two
// seconds.
Item {
    id: poll

    readonly property bool shown: QsWindow.window?.visible ?? false

    signal poll

    visible: false
    onShownChanged: if (shown)
        quick.restart()

    Timer {
        interval: 2000
        running: poll.shown
        repeat: true
        triggeredOnStart: true
        onTriggered: poll.poll()
    }

    Timer {
        id: quick

        interval: 500
        onTriggered: poll.poll()
    }
}
