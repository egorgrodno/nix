import QtQuick

// A glyph on a square button, filled while `lit`, with a tooltip.
TextButton {
    id: button

    property string tip

    width: 32
    height: 32
    textColor: Theme.foregroundMuted
    litTextColor: Theme.foregroundStrong

    Tooltip {
        target: button
        text: button.tip
        hovered: button.hovered
    }
}
