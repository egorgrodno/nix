import QtQuick
import Quickshell

Pill {
    text: "⏻"
    textColor: hovered ? "#ffffff" : Theme.red
    hoverFill: Theme.alpha(Theme.red, 0.5)
    onClicked: button => {
        if (button === Qt.LeftButton)
            Quickshell.execDetached([Programs.wlogout]);
    }
}
