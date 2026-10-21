pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets

// One app's notifications in the panel. From two on, a header with the app's
// icon and name, the count, a chevron and a clear button sits over the cards,
// of which a collapsed group shows only the newest; a click on the header opens
// or closes it. The group's height eases, clipping, so the older cards come out
// from under the newest and go back.
Item {
    id: group

    // The key, by which the panel looks up `entries`.
    required property string modelData
    // Newest first.
    property var entries: []
    property bool expanded: true
    property bool slideIn: true
    // A group that empties keeps its last cards, so they leave with it.
    property var shown: []
    readonly property var newest: shown[0] ?? null
    readonly property bool headed: shown.length > 1
    readonly property string icon: newest === null || newest.appIcon === "" || newest.appIcon.startsWith("/") || newest.appIcon.startsWith("file://") ? "" : Quickshell.iconPath(newest.appIcon, true)
    // The newest card's height, which a collapsed group shows. Found by index,
    // which notifies, unlike itemAtIndex(); a card leaving has -1.
    readonly property real firstHeight: cards.contentItem.children.find(c => c.index === 0)?.height ?? 0
    // From just after the first layout, from when heights ease.
    property bool settled: false

    signal toggled

    width: ListView.view.width
    height: header.height + drawer.height

    onEntriesChanged: if (entries.length > 0)
        shown = entries
    Component.onCompleted: {
        shown = entries;
        Qt.callLater(() => settled = true);
    }

    Item {
        id: header

        width: parent.width
        // With the gap to the cards.
        height: group.headed ? row.height + 8 : 0
        opacity: group.headed ? 1 : 0
        visible: opacity > 0

        Behavior on height {
            enabled: group.settled

            NumberAnimation {
                duration: 200
                easing.type: Easing.OutExpo
            }
        }

        Behavior on opacity {
            enabled: group.settled

            NumberAnimation {
                duration: 200
                easing.type: Easing.OutExpo
            }
        }

        MouseArea {
            id: headerMouse

            width: parent.width
            height: row.height
            hoverEnabled: true
            onClicked: group.toggled()
        }

        Item {
            id: row

            width: parent.width
            height: Math.max(name.implicitHeight, chevron.implicitHeight)

            Row {
                anchors.left: parent.left
                anchors.right: buttons.left
                anchors.rightMargin: 12
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                IconImage {
                    id: icon

                    anchors.verticalCenter: parent.verticalCenter
                    visible: group.icon !== ""
                    implicitSize: 16
                    source: group.icon
                }

                BarText {
                    id: name

                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, parent.width - (icon.visible ? icon.width + parent.spacing : 0) - count.width - parent.spacing)
                    text: group.newest ? Notifications.appLabel(group.newest) : ""
                    elide: Text.ElideRight
                    font.pixelSize: 14
                }

                Figure {
                    id: count

                    anchors.baseline: name.baseline
                    text: `${group.shown.length}`
                    color: Theme.foregroundMuted
                    font.pixelSize: 14
                }
            }

            Row {
                id: buttons

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 12

                BarText {
                    id: chevron

                    anchors.verticalCenter: parent.verticalCenter
                    text: group.expanded ? "\u{F0143}" : "\u{F0140}"
                    color: headerMouse.containsMouse ? Theme.foregroundStrong : Theme.foregroundMuted
                }

                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{F0156}"
                    color: clearMouse.containsMouse ? Theme.foregroundStrong : Theme.foregroundMuted

                    MouseArea {
                        id: clearMouse

                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        onClicked: Notifications.clear(group.shown)
                    }
                }
            }
        }
    }

    Item {
        id: drawer

        y: header.height
        width: parent.width
        height: group.expanded ? cards.contentHeight : group.firstHeight
        // Only while it hides cards, so a lone card slides in unclipped.
        clip: group.headed && !group.expanded || ease.running

        Behavior on height {
            enabled: group.settled

            NumberAnimation {
                id: ease

                duration: 200
                easing.type: Easing.OutExpo
            }
        }

        ListView {
            id: cards

            width: parent.width
            height: contentHeight
            interactive: false
            spacing: 8
            model: ScriptModel {
                values: [...group.shown]
            }
            delegate: NotificationCard {
                required property int index

                showTime: true
                showApp: !group.headed
                slideIn: group.slideIn && entry.time > Notifications.seenAt
                fill: Theme.tint(0.04)
            }

            displaced: Transition {
                NumberAnimation {
                    property: "y"
                    duration: 200
                    easing.type: Easing.OutExpo
                }
            }

            move: Transition {
                NumberAnimation {
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 200
                    easing.type: Easing.OutExpo
                }
            }

            remove: Transition {
                NumberAnimation {
                    property: "x"
                    to: cards.width
                    duration: 200
                    easing.type: Easing.OutExpo
                }

                NumberAnimation {
                    property: "opacity"
                    to: 0
                    duration: 200
                    easing.type: Easing.OutExpo
                }
            }
        }
    }
}
