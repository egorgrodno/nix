import QtQuick

// A ‹ or › that steps whatever it sits beside, by `by`.
BarText {
    id: chevron

    property int by

    signal stepped(int by)

    width: 28
    height: 28
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    text: by < 0 ? "\u{F0141}" : "\u{F0142}"
    font.pixelSize: 20
    color: hover.hovered ? Theme.foregroundStrong : Theme.foregroundMuted

    HoverHandler {
        id: hover
    }

    TapHandler {
        onTapped: chevron.stepped(chevron.by)
    }
}
