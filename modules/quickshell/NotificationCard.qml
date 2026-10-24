import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Widgets

// A notification: the app's icon and name, the summary, and the body clipped
// to three lines with an expander for the rest; an image at the leading side,
// a meter for a `value` hint, a button per action, and a reply field where the
// sender takes one. A click invokes the default action, or dismisses where
// there is none; a right-click dismisses, as does a drag right past a third of
// the width. Hovering holds the timer, as replying does.
// The panel shows each card's age, without the app's name and icon under a
// group's header, and slides in only those that arrive while it is open. A
// popup casts a shadow over the windows.
Item {
    id: card

    required property var modelData
    readonly property var entry: modelData
    property bool expanded: false
    property bool showTime: false
    property bool showApp: true
    property bool slideIn: true
    property bool raised: false
    property color fill: Theme.alpha(Theme.backgroundRaised, 0.97)
    // Set once created, so the card slides out of the bar as it fades in.
    property bool arrived: !slideIn
    readonly property var defaultAction: entry.actions.find(a => a.identifier === "default") ?? null
    readonly property bool replying: Notifications.replying === entry
    // An app icon given as a file is usually a picture, as notify-send -i
    // passes one.
    readonly property bool iconIsFile: entry.appIcon.startsWith("/") || entry.appIcon.startsWith("file://")
    readonly property string picture: entry.image !== "" ? entry.image : iconIsFile ? (entry.appIcon.startsWith("/") ? `file://${entry.appIcon}` : entry.appIcon) : ""
    readonly property string icon: !showApp || entry.appIcon === "" || iconIsFile ? "" : Quickshell.iconPath(entry.appIcon, true)
    // Lines as breaks, and no images, which the server does not advertise.
    readonly property string bodyText: entry.body.replace(/<img\b[^>]*>/gi, "").replace(/\n/g, "<br>")

    function activate() {
        if (defaultAction)
            defaultAction.invoke();
        else
            entry.dismiss();
    }

    // Which closes the notification, unless it is resident.
    function send() {
        if (field.text === "")
            return;
        entry.notification?.sendInlineReply(field.text);
        field.text = "";
        Notifications.replying = null;
    }

    width: ListView.view.width
    height: box.height

    Component.onCompleted: arrived = true
    // A card that goes while hovered or replying, as the panel closes, would
    // otherwise leave the entry's timer held should it pop up again.
    Component.onDestruction: {
        if (hover.hovered)
            entry.hovered = false;
        if (replying)
            Notifications.replying = null;
    }
    // Back to the card, so that in the panel Escape still reaches it.
    onReplyingChanged: {
        if (replying)
            field.forceActiveFocus();
        else if (field.activeFocus)
            card.forceActiveFocus();
    }

    // In the panel, a press outside the reply ends it, as Escape does; a popup
    // has no such signal.
    Connections {
        target: card.QsWindow.window
        enabled: card.replying
        ignoreUnknownSignals: true

        function onPressed(position) {
            if (!field.contains(field.mapFromItem(null, position)) && !sendMouse.contains(sendMouse.mapFromItem(null, position)))
                Notifications.replying = null;
        }
    }

    HoverHandler {
        id: hover

        onHoveredChanged: card.entry.hovered = hovered
    }

    // Handlers rather than a MouseArea, so a press reaches the drag as well;
    // links and buttons above take their own.
    TapHandler {
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        onTapped: (eventPoint, button) => {
            if (button === Qt.RightButton)
                card.entry.dismiss();
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
                card.entry.dismiss();
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

    Shadow {
        visible: card.raised
        target: box
    }

    Rectangle {
        id: box

        width: parent.width
        height: content.implicitHeight + 2 * 16
        y: card.arrived ? 0 : -Theme.slide
        opacity: card.arrived ? 1 : 0
        color: card.fill
        border.color: card.entry.urgency === NotificationUrgency.Critical ? Theme.red : Theme.tint(0.08)
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

                // Also none for a file gone since, as a sender's temporary one.
                visible: card.picture !== "" && image.status !== Image.Error
                width: 48
                height: 48
                radius: Theme.radius - 4
                color: "transparent"

                Image {
                    id: image

                    anchors.fill: parent
                    source: card.picture
                    sourceSize.width: 96
                    sourceSize.height: 96
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true

                    // An `image-data` image dies with its notification, and a
                    // file may, so the first card to show one saves it for the
                    // history.
                    onStatusChanged: {
                        const entry = card.entry;
                        const source = entry.imageSource;
                        if (status !== Image.Ready || !entry.imageFleeting || entry.imageFile !== "")
                            return;
                        const path = Quickshell.statePath(`notifications/${Math.round(entry.time)}-${Math.random().toString(36).slice(2, 8)}.png`);
                        grabToImage(result => {
                            if (entry.imageSource === source && entry.imageFile === "" && result.saveToFile(path)) {
                                entry.imageFile = path;
                                Notifications.save();
                            }
                        }, Qt.size(96, 96));
                    }
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
                            readonly property string app: card.showApp ? Notifications.appLabel(card.entry) : ""

                            text: app === "" ? Notifications.ageOf(card.entry.time) : card.showTime ? `${app} · ${Notifications.ageOf(card.entry.time)}` : app
                            elide: Text.ElideRight
                        }
                    }

                    BarText {
                        id: expander

                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: card.expanded || summary.truncated || body.truncated
                        text: card.expanded ? "\u{F0143}" : "\u{F0140}"
                        color: expanderMouse.containsMouse ? Theme.foregroundStrong : Theme.foregroundMuted
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
                    onLinkActivated: link => Launcher.run([Programs.xdgOpen, link])
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

                Item {
                    width: parent.width
                    height: reply.height + 8
                    visible: card.entry.hasInlineReply

                    Rectangle {
                        id: reply

                        y: 8
                        width: parent.width
                        height: 32
                        radius: Theme.radius - 4
                        color: Theme.tint(0.06)
                        border.color: card.replying ? Theme.blue : "transparent"
                        border.width: 1

                        TextInput {
                            id: field

                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.right: sendButton.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            clip: true
                            color: Theme.foregroundStrong
                            selectionColor: Theme.blue
                            selectByMouse: true
                            font.family: Theme.fontUI
                            font.pixelSize: 14
                            font.hintingPreference: Font.PreferFullHinting
                            renderType: Text.CurveRendering
                            Keys.onReturnPressed: card.send()
                            Keys.onEnterPressed: card.send()
                            Keys.onEscapePressed: Notifications.replying = null

                            BarText {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: field.text === ""
                                text: card.entry.replyPlaceholder !== "" ? card.entry.replyPlaceholder : "Reply"
                                color: Theme.foregroundMuted
                                font.pixelSize: 14
                            }
                        }

                        // The click that starts a reply, which the card's own
                        // tap would otherwise take; the field takes those after.
                        MouseArea {
                            anchors.fill: parent
                            enabled: !card.replying
                            cursorShape: Qt.IBeamCursor
                            onClicked: Notifications.replying = card.entry
                        }

                        BarText {
                            id: sendButton

                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            text: "\u{F048A}"
                            color: field.text !== "" && sendMouse.containsMouse ? Theme.foregroundStrong : Theme.foregroundMuted

                            MouseArea {
                                id: sendMouse

                                anchors.fill: parent
                                anchors.margins: -6
                                hoverEnabled: true
                                onClicked: card.send()
                            }
                        }
                    }
                }
            }
        }
    }
}
