import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// Newest item first, passive items hidden, and no module at all when nothing
// is left, as Waybar's tray with `reverse-direction` behaves.
Pill {
    id: tray

    readonly property var items: SystemTray.items.values.filter(i => i.status !== Status.Passive).reverse()

    visible: items.length > 0

    Repeater {
        model: ScriptModel {
            values: tray.items
        }

        Item {
            id: entry

            required property SystemTrayItem modelData

            width: 24
            height: tray.height - 10
            anchors.verticalCenter: parent.verticalCenter

            IconImage {
                anchors.centerIn: parent
                implicitSize: 24
                source: entry.modelData.icon
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                onPressed: event => {
                    tip.dismiss();
                    if (event.button === Qt.MiddleButton)
                        entry.modelData.secondaryActivate();
                    else if (event.button === Qt.RightButton || entry.modelData.onlyMenu) {
                        if (entry.modelData.hasMenu) {
                            menu.anchor.rect.x = event.x;
                            menu.anchor.rect.y = event.y;
                            menu.open();
                        }
                    } else
                        entry.modelData.activate();
                }
                onWheel: event => entry.modelData.scroll(event.angleDelta.y > 0 ? 1 : -1, false)
            }

            // At the pointer, as GTK's popup_at_pointer places it.
            QsMenuAnchor {
                id: menu

                menu: entry.modelData.menu
                anchor.item: entry
                anchor.rect.width: 1
                anchor.rect.height: 1
                anchor.edges: Edges.Bottom | Edges.Right
                anchor.gravity: Edges.Bottom | Edges.Right
            }

            Tooltip {
                id: tip

                target: entry
                text: entry.modelData.tooltipTitle || entry.modelData.title
                hovered: mouse.containsMouse
                pointerX: mouse.mouseX
            }
        }
    }
}
