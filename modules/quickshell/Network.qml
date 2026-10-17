import QtQuick
import Quickshell

Pill {
    visible: text !== ""
    text: Stats.network
    onClicked: button => {
        if (button === Qt.LeftButton)
            Quickshell.execDetached([Programs.nmConnectionEditor]);
    }
}
