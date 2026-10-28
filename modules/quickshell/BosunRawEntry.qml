import QtQuick

// An entry the panel cannot render, in a dashed yellow box: its type, then
// its raw JSON on one line, whole at a click on Raw.
Item {
    id: raw

    // What it is, such as "attachment/edited_text_file".
    property string type
    property var json
    property bool open: false
    readonly property string flat: JSON.stringify(json) ?? ""

    signal toggled

    width: parent?.width ?? 0
    height: body.implicitHeight + 20

    BosunDashed {}

    Column {
        id: body

        x: 12
        y: 10
        width: parent.width - 24
        spacing: 4

        BosunLine {
            glyph: BosunLook.alert
            glyphColor: Theme.yellow
            label: "bosun can't show this entry yet"
            labelColor: Theme.yellow
            aside: raw.type
            asideColor: Theme.yellow
            asideMono: true
            open: raw.open
            onToggled: raw.toggled()
        }

        BarText {
            width: parent.width
            text: raw.open ? JSON.stringify(raw.json, null, 2) ?? "" : raw.flat
            elide: raw.open ? Text.ElideNone : Text.ElideRight
            wrapMode: raw.open ? Text.WrapAnywhere : Text.NoWrap
            maximumLineCount: raw.open ? 400 : 1
            color: Theme.foregroundMain
            font.family: Theme.fontMono
            font.pixelSize: 12
        }
    }
}
