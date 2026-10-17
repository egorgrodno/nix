import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

// A notification: the app's icon and name, the summary, and the body clipped
// to three lines with an expander for the rest; an image at the leading side,
// a meter for a `value` hint, and a button per action. A click invokes the
// default action, or dismisses where there is none; a right-click dismisses,
// as does a drag right past a third of the width. Hovering holds the timer.
Item {
    id: card

    required property var modelData
    readonly property var entry: modelData
    property bool expanded: false
    // Set once created, so the card slides out of the bar as it fades in.
    property bool arrived: false
    readonly property var defaultAction: entry.actions.find(a => a.identifier === "default") ?? null
    // An app icon given as a file is usually a picture, as notify-send -i
    // passes one.
    readonly property bool iconIsFile: entry.appIcon.startsWith("/") || entry.appIcon.startsWith("file://")
    readonly property string picture: entry.image !== "" ? entry.image : iconIsFile ? (entry.appIcon.startsWith("/") ? `file://${entry.appIcon}` : entry.appIcon) : ""
    readonly property string icon: entry.appIcon === "" || iconIsFile ? "" : Quickshell.iconPath(entry.appIcon, true)
    // Lines as breaks, and no images, which the server does not advertise.
    readonly property string bodyText: entry.body.replace(/<img\b[^>]*>/gi, "").replace(/\n/g, "<br>")

    function activate() {
        if (defaultAction)
            defaultAction.invoke();
        else
            entry.notification?.dismiss();
    }

    width: ListView.view.width
    height: box.height

    Component.onCompleted: arrived = true

    HoverHandler {
        onHoveredChanged: card.entry.hovered = hovered
    }

    // Handlers rather than a MouseArea, so a press reaches the drag as well;
    // links and buttons above take their own.
    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: (eventPoint, button) => {
            if (button === Qt.RightButton)
                card.entry.notification?.dismiss();
            else
                card.activate();
        }
    }

    DragHandler {
        id: drag

        yAxis.enabled: false
        xAxis.minimum: 0
        onActiveChanged: {
            if (active)
                return;
            if (card.x > card.width / 3)
                card.entry.notification?.dismiss();
            else
                springBack.start();
        }
    }

    NumberAnimation {
        id: springBack

        target: card
        property: "x"
        to: 0
        duration: 200
        easing.type: Easing.OutExpo
    }

    Rectangle {
        id: box

        width: parent.width
        height: content.implicitHeight + 2 * 16
        y: card.arrived ? 0 : -Theme.slide
        opacity: card.arrived ? 1 : 0
        color: Theme.alpha(Theme.backgroundMain, 0.97)
        border.color: card.entry.urgency === NotificationUrgency.Critical ? Theme.red : Qt.rgba(1, 1, 1, 0.08)
        border.width: 1
        radius: Theme.radius
        clip: true

        // One curve both ways, as in Panel.qml.
        Behavior on y {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutExpo
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutExpo
            }
        }

        Behavior on height {
            enabled: card.arrived

            NumberAnimation {
                duration: 200
                easing.type: Easing.OutExpo
            }
        }

        Row {
            id: content

            x: 16
            y: 16
            width: parent.width - 2 * 16
            spacing: 12

            ClippingRectangle {
                id: picture

                visible: card.picture !== ""
                width: 48
                height: 48
                radius: Theme.radius - 4
                color: "transparent"

                Image {
                    anchors.fill: parent
                    source: card.picture
                    sourceSize.width: 96
                    sourceSize.height: 96
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                }
            }

            Column {
                width: parent.width - (picture.visible ? picture.width + parent.spacing : 0)
                spacing: 4

                Item {
                    width: parent.width
                    height: appName.implicitHeight

                    Row {
                        anchors.left: parent.left
                        anchors.right: expander.left
                        anchors.rightMargin: 8
                        spacing: 6

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: card.icon !== ""
                            implicitSize: 16
                            source: card.icon
                        }

                        Caption {
                            id: appName

                            width: parent.width - (card.icon !== "" ? 16 + parent.spacing : 0)
                            text: card.entry.appName
                            elide: Text.ElideRight
                        }
                    }

                    BarText {
                        id: expander

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: card.expanded || summary.truncated || body.truncated
                        text: card.expanded ? "\u{F0143}" : "\u{F0140}"
                        color: expanderMouse.containsMouse ? "#ffffff" : Theme.foregroundMuted
                        font.pixelSize: 16

                        MouseArea {
                            id: expanderMouse

                            anchors.fill: parent
                            anchors.margins: -6
                            hoverEnabled: true
                            onClicked: card.expanded = !card.expanded
                        }
                    }
                }

                BarText {
                    id: summary

                    width: parent.width
                    visible: text !== ""
                    text: card.entry.summary
                    wrapMode: Text.Wrap
                    maximumLineCount: card.expanded ? undefined : 2
                    elide: Text.ElideRight
                }

                BarText {
                    id: body

                    width: parent.width
                    visible: text !== ""
                    text: card.bodyText
                    textFormat: Text.StyledText
                    color: Theme.foregroundMuted
                    font.pixelSize: 14
                    wrapMode: Text.Wrap
                    maximumLineCount: card.expanded ? undefined : 3
                    elide: Text.ElideRight
                    linkColor: Theme.blue
                    onLinkActivated: link => Quickshell.execDetached([Programs.xdgOpen, link])
                }

                // Clear of the text above it.
                Item {
                    width: parent.width
                    height: 12
                    visible: card.entry.value >= 0

                    Meter {
                        anchors.bottom: parent.bottom
                        width: parent.width
                        value: card.entry.value / 100
                        graded: false
                    }
                }

                Flow {
                    width: parent.width
                    topPadding: 8
                    spacing: 8
                    visible: actions.count > 0

                    Repeater {
                        id: actions

                        model: card.entry.actions.filter(a => a.identifier !== "default")

                        TextButton {
                            required property var modelData

                            text: modelData.text
                            onClicked: modelData.invoke()
                        }
                    }
                }
            }
        }
    }
}
