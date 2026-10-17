import QtQuick
import Quickshell
import Quickshell.Wayland

// The popups, on the focused screen, top right under the top bar, newest on
// top, taking input only on the cards. On `overlay`, the only layer Hyprland
// draws over a fullscreen window, and ordered beneath the panels there by a
// layer rule. A card leaves sliding right, and the rest ease into its place.
PanelWindow {
    id: popups

    screen: Notifications.screen
    // Mapped imperatively, so the window outlives the last card's exit.
    visible: false
    anchors {
        top: true
        right: true
        bottom: true
    }
    // Reaching over the bar as far as a card slides, as a panel does.
    margins {
        top: Theme.barHeight + 4 - Theme.slide
        bottom: Theme.barHeight + 4
    }
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 360 + Theme.outerGap
    color: "transparent"
    mask: Region {
        item: list.contentItem
    }
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-notifications"

    Connections {
        target: Notifications

        function onPopupsChanged() {
            if (Notifications.popups.length > 0) {
                unmap.stop();
                popups.visible = true;
            } else {
                unmap.restart();
            }
        }
    }

    Timer {
        id: unmap

        interval: 400
        onTriggered: popups.visible = false
    }

    ListView {
        id: list

        y: Theme.slide
        width: 360
        height: parent.height - Theme.slide
        spacing: 8
        interactive: false
        model: ScriptModel {
            // An array rather than the list property, which it cannot take.
            values: [...Notifications.popups]
        }
        delegate: NotificationCard {}

        displaced: Transition {
            NumberAnimation {
                property: "y"
                duration: 200
                easing.type: Easing.OutExpo
            }
        }

        remove: Transition {
            NumberAnimation {
                property: "x"
                to: list.width
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
