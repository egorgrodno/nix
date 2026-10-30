import QtQuick
import Quickshell
import Quickshell.Hyprland

// The screen's workspaces by number over a dot per window, up to four, and the
// focused one marked along the bottom edge. A workspace showing on another
// screen is not marked. One opens as it appears and closes as it goes, and one
// taking another's place slides its number in from the side its id lies on.
Row {
    id: workspaces

    required property HyprlandMonitor monitor
    // An empty workspace counts as gone once it leaves the screen, because
    // Hyprland destroys it only after the next one has arrived, and the two
    // must land in one sync for the next to take its slot.
    readonly property var current: Hyprland.workspaces.values.filter(w => w.id > 0 && w.monitor === workspaces.monitor && (w.active || w.toplevels.values.length > 0)).sort((a, b) => a.id - b.id)
    // Off while Quickshell fills in the workspaces and then their windows, a
    // request at a time, so the bar starts with them open.
    property bool settled

    // Each slot is a workspace by id, kept while it closes. One arriving
    // beside a closing slot takes it over and slides its number in.
    function sync() {
        const ids = current.map(w => w.id);
        // Backwards, as a slot that closes at once drops out under the loop.
        for (let i = slots.count - 1; i >= 0; i--)
            slots.setProperty(i, "leaving", !ids.includes(slots.get(i).wsId));
        for (const id of ids) {
            let at = 0;
            while (at < slots.count && slots.get(at).wsId < id)
                at++;
            if (at < slots.count && slots.get(at).wsId === id)
                continue;
            const near = [at - 1, at].find(i => i >= 0 && i < slots.count && slots.get(i).leaving);
            if (near !== undefined)
                slots.set(near, {
                    wsId: id,
                    leaving: false
                });
            else
                slots.insert(at, {
                    wsId: id,
                    leaving: false
                });
        }
    }

    function drop(id) {
        for (let i = 0; i < slots.count; i++) {
            if (slots.get(i).wsId === id && slots.get(i).leaving) {
                slots.remove(i);
                return;
            }
        }
    }

    onCurrentChanged: sync()
    Component.onCompleted: sync()

    Timer {
        running: true
        interval: 1000
        onTriggered: workspaces.settled = true
    }

    ListModel {
        id: slots
    }

    Repeater {
        model: slots

        Item {
            id: button

            required property int wsId
            required property bool leaving
            readonly property HyprlandWorkspace workspace: workspaces.current.find(w => w.id === wsId) ?? null
            readonly property int windows: workspace?.toplevels.values.length ?? 0
            readonly property bool urgent: workspace?.urgent ?? false
            readonly property bool focused: workspace?.focused ?? false
            readonly property real full: Math.max(40, label.implicitWidth + 24)
            property bool opened
            // The id and name it slides away from, with side 1 for a higher id
            // coming in from the right and -1 for a lower one from the left.
            property int shownId
            property string pastName
            property int side: 1
            property real slid: 1

            function dropIfClosed() {
                if (leaving && width === 0)
                    workspaces.drop(wsId);
            }

            width: opened && !leaving ? full : 0
            height: parent.height
            clip: true
            onWidthChanged: dropIfClosed()
            onLeavingChanged: dropIfClosed()
            onWsIdChanged: {
                // Set at creation too, before there is a number to slide from.
                if (!opened)
                    return;
                side = wsId > shownId ? 1 : -1;
                pastName = String(shownId);
                shownId = wsId;
                sliding.restart();
            }
            Component.onCompleted: {
                shownId = wsId;
                opened = true;
            }

            // One curve both ways, as in Panel.qml.
            Behavior on width {
                enabled: workspaces.settled

                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutExpo
                }
            }

            NumberAnimation {
                id: sliding

                target: button
                property: "slid"
                from: 0
                to: 1
                duration: 200
                easing.type: Easing.OutExpo
            }

            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: button.full
                height: parent.height
                opacity: button.opened && !button.leaving ? 1 : 0

                Behavior on opacity {
                    enabled: workspaces.settled

                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutExpo
                    }
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 4
                    radius: Theme.radius - 4
                    color: button.urgent ? Theme.alpha(Theme.red, 0.6) : mouse.containsMouse ? Theme.tint(0.07) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                Item {
                    id: number

                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: -3
                    width: label.implicitWidth
                    height: label.implicitHeight

                    BarText {
                        id: label

                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: button.side * button.full / 2 * (1 - button.slid)
                        opacity: button.slid
                        // The id while it closes, its workspace no longer listed.
                        text: button.workspace?.name ?? String(button.wsId)
                        color: button.windows === 0 && !button.urgent ? Theme.foregroundMuted : Theme.foregroundStrong
                        font.family: Theme.fontMono
                    }

                    BarText {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: -button.side * button.full / 2 * button.slid
                        opacity: 1 - button.slid
                        visible: button.slid < 1
                        text: button.pastName
                        color: Theme.foregroundMuted
                        font.family: Theme.fontMono
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: number.bottom
                    anchors.topMargin: 1
                    spacing: 3

                    Repeater {
                        model: Math.min(button.windows, 4)

                        Rectangle {
                            width: 3
                            height: 3
                            radius: 1.5
                            color: button.focused ? Theme.blue : Theme.foregroundMuted
                        }
                    }
                }

                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 12
                    height: 3
                    topLeftRadius: 1.5
                    topRightRadius: 1.5
                    color: Theme.blue
                    visible: button.focused
                }
            }

            MouseArea {
                id: mouse

                anchors.fill: parent
                hoverEnabled: true
                onClicked: button.workspace?.activate()
            }
        }
    }
}
