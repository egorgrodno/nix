import QtQuick

// One of a row of buttons, of which the `lit` one is the choice: blue under
// the panel's dark text.
TextButton {
    hoverFill: lit ? Theme.blue : Theme.tint(0.12)
    textColor: lit ? Theme.backgroundMain : Theme.foregroundStrong
}
