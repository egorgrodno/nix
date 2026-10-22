import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import Quickshell.Widgets

// Newest item first, passive items hidden, and no module at all when nothing
// is left. Each icon lights on hover rather than the module. nm-applet runs
// only as NetworkManager's secret agent, so its icon is hidden too: the
// network module stands in for it.
Pill {
    id: tray

    readonly property var items: SystemTray.items.values.filter(i => i.status !== Status.Passive && i.id !== "nm-applet").reverse()
    readonly property bool upward: {
        const anchors = QsWindow.window?.anchors;
        return anchors?.bottom === true && anchors?.top !== true;
    }

    visible: items.length > 0
    hoverable: false

    Repeater {
        model: ScriptModel {
            values: tray.items
        }

        Item {
            id: entry

            required property SystemTrayItem modelData

            width: 20
            height: tray.height - 10
            anchors.verticalCenter: parent.verticalCenter

            // Inset from the segment as a module's fill is, and reaching halfway
            // into the gap on either side, so neighbours' fills meet.
            Item {
                id: area

                x: -4
                y: 4 - entry.y
                width: entry.width + 8
                height: tray.height - 8

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius - 4
                    color: mouse.containsMouse ? tray.hoverFill : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }
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
                                menu.anchor.rect.x = area.x + event.x;
                                menu.anchor.rect.y = area.y + event.y;
                                menu.open();
                            }
                        } else
                            entry.modelData.activate();
                    }
                    onWheel: event => entry.modelData.scroll(event.angleDelta.y > 0 ? 1 : -1, false)
                }
            }

            IconImage {
                anchors.centerIn: parent
                implicitSize: 20
                source: entry.modelData.icon
            }

            // At the pointer, as GTK's popup_at_pointer places it, and upward on a
            // bar along the bottom edge.
            QsMenuAnchor {
                id: menu

                menu: entry.modelData.menu
                anchor.item: entry
                anchor.rect.width: 1
                anchor.rect.height: 1
                anchor.edges: (tray.upward ? Edges.Top : Edges.Bottom) | Edges.Right
                anchor.gravity: (tray.upward ? Edges.Top : Edges.Bottom) | Edges.Right
            }

            Tooltip {
                id: tip

                target: entry
                text: entry.modelData.tooltipTitle || entry.modelData.title
                hovered: mouse.containsMouse
                pointerX: area.x + mouse.mouseX
            }
        }
    }
}
