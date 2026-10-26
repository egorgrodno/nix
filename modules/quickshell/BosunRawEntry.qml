import QtQuick
import QtQuick.Shapes

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

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeColor: Theme.alpha(Theme.yellow, 0.6)
            strokeWidth: 1
            strokeStyle: ShapePath.DashLine
            dashPattern: [4, 3]
            fillColor: Theme.alpha(Theme.yellow, 0.05)

            PathRectangle {
                x: 0.5
                y: 0.5
                width: raw.width - 1
                height: raw.height - 1
                radius: 4
            }
        }
    }

    Column {
        id: body

        x: 12
        y: 10
        width: parent.width - 24
        spacing: 4

        Item {
            width: parent.width
            height: title.implicitHeight

            Row {
                id: title

                spacing: 8

                BarText {
                    text: `${BosunLook.alert}  bosun can't show this entry yet`
                    color: Theme.yellow
                    font.pixelSize: 13
                }

                BarText {
                    text: raw.type
                    color: Theme.yellow
                    font.family: Theme.fontMono
                    font.pixelSize: 13
                }
            }

            Caption {
                anchors.right: parent.right
                text: `Raw  ${raw.open ? BosunLook.chevronDown : BosunLook.chevronRight}`

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -4
                    cursorShape: Qt.PointingHandCursor
                    onClicked: raw.toggled()
                }
            }
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
