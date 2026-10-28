import QtQuick

// What a session does: its tool's glyph and the call in monospace, or the
// start of its last message. The glyph font's ink sits about 4.5 px above
// its baseline at this size, the call's x-height centre 4 px above its own
// and the message's 3.5 px, so the baselines are aligned and the glyph
// drops 1 px beside the message.
Item {
    id: line

    required property var activity
    required property color tint
    readonly property bool mono: BosunLook.activityMono(activity)
    readonly property real lineBase: Math.max(lineText.baselineOffset, lineGlyph.baselineOffset - drop)
    readonly property real drop: mono ? 0 : 1

    height: 18

    BarText {
        id: lineGlyph

        y: line.lineBase + line.drop - baselineOffset
        text: line.activity ? BosunLook.activityGlyph(line.activity) : ""
        color: line.tint
        font.pixelSize: 12
    }

    BarText {
        id: lineText

        x: lineGlyph.width + 6
        y: line.lineBase - baselineOffset
        width: parent.width - x
        elide: Text.ElideRight
        text: line.activity ? BosunLook.activityText(line.activity) : ""
        color: line.tint
        font.family: line.mono ? Theme.fontMono : Theme.fontUI
        font.pixelSize: 12
    }
}
