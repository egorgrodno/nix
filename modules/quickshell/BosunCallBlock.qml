import QtQuick

// A part of a call, whole under its label, on a tint that marks what it is:
// one of the blocks `Bosun.callOf` makes.
Column {
    id: block

    required property var modelData
    readonly property string kind: modelData.kind
    readonly property bool mono: ["code", "removed", "added"].includes(kind)
    readonly property bool boxed: kind !== "note"

    width: parent?.width ?? 0
    spacing: 4

    Caption {
        visible: block.modelData.label !== ""
        text: block.modelData.label
    }

    Rectangle {
        width: block.kind === "flag" ? Math.min(parent.width, blockText.implicitWidth + 2 * blockText.x) : parent.width
        height: blockText.implicitHeight + 2 * blockText.y
        radius: 4
        color: {
            switch (block.kind) {
            case "removed":
                return Theme.alpha(Theme.red, 0.15);
            case "added":
                return Theme.alpha(Theme.green, 0.15);
            case "flag":
                return Theme.alpha(Theme.yellow, 0.15);
            case "note":
                return "transparent";
            }
            return Theme.tint(0.06);
        }

        SelectableText {
            id: blockText

            x: block.boxed ? (block.kind === "flag" ? 8 : 12) : 0
            y: block.boxed ? (block.kind === "flag" ? 3 : 10) : 0
            width: parent.width - 2 * x
            wrapMode: TextEdit.Wrap
            font.family: block.mono ? Theme.fontMono : Theme.fontUI
            font.pixelSize: block.mono ? 13 : 14
            color: block.kind === "flag" ? Theme.yellow : block.kind === "note" ? Theme.foregroundMain : Theme.foregroundStrong
            text: block.kind === "flag" ? `${BosunLook.alert}  ${block.modelData.text}` : block.modelData.text
        }
    }
}
