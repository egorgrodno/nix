import QtQuick
import Quickshell

// Over the power module: the session's actions, one to a row with its key,
// which a click or the key runs. No row is selected; only the pointer lights
// one.
Panel {
    id: panel

    function run(action) {
        // Once, though a held key repeats while the panel fades.
        if (!open)
            return;
        close();
        Quickshell.execDetached(action.command);
    }

    boxWidth: 240
    // With the rows' own 8 px inset, the text sits 20 px in, as any panel's
    // content does.
    padding: 12

    // Takes the keyboard from the box, which still gets Escape: a key not
    // taken here passes up to it.
    Column {
        id: rows

        width: panel.contentWidth
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: event => {
            const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
            const action = Session.actions.find(a => a.key === event.key && !!a.shift === shift);
            if (action) {
                event.accepted = true;
                panel.run(action);
            }
        }

        Repeater {
            model: Session.actions

            Item {
                id: row

                required property var modelData

                width: rows.width
                height: 36

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius - 4
                    color: hover.hovered ? Theme.tint(0.07) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                HoverHandler {
                    id: hover
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: panel.run(row.modelData)
                }

                // A fixed slot, so the labels line up whatever the glyph's width.
                BarText {
                    id: glyph

                    x: 8
                    width: 20
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: row.modelData.glyph
                    font.pixelSize: 18
                }

                BarText {
                    anchors.left: glyph.right
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: row.modelData.label
                }

                // The character the key types.
                BarText {
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: {
                        const letter = String.fromCharCode(row.modelData.key);
                        return row.modelData.shift ? letter : letter.toLowerCase();
                    }
                    color: Theme.foregroundMuted
                    font.family: Theme.fontMono
                    font.pixelSize: 14
                }
            }
        }
    }
}
