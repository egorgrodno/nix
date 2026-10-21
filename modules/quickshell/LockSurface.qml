import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland

// One screen's lock: the wallpaper blurred and dimmed, the time over the date,
// and the login card, which fade in together once the wallpaper has loaded.
// Keys alone unlock, so the pointer hides over it.
WlSessionLockSurface {
    id: surface

    // The Lock that made it.
    property var lock
    readonly property string wallpaper: Wallpapers.saved !== "" ? Wallpapers.saved : Wallpapers.shown

    color: Theme.backgroundMain

    Item {
        id: content

        anchors.fill: parent
        focus: true
        opacity: picture.status === Image.Loading ? 0 : 1
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: event => event.accepted = surface.lock.password.key(event)
        Keys.onReleased: event => {
            if (event.key === Qt.Key_CapsLock)
                surface.lock.caps.update();
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 300
                easing.type: Easing.OutCubic
            }
        }

        // Decoded small, which the blur hides and which keeps the lock quick.
        Image {
            id: picture

            anchors.fill: parent
            visible: false
            source: surface.wallpaper !== "" ? "file://" + surface.wallpaper.split("/").map(encodeURIComponent).join("/") : ""
            sourceSize.width: 960
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }

        MultiEffect {
            anchors.fill: parent
            visible: picture.status === Image.Ready
            source: picture
            autoPaddingEnabled: false
            blurEnabled: true
            blur: 1
            blurMax: 48
            brightness: -0.3
        }

        BigClock {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: card.top
            anchors.bottomMargin: 48
        }

        LoginCard {
            id: card

            // Its top fixed, so a message grows it downward only.
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.verticalCenter
            user: surface.lock.user
            length: surface.lock.password.text.length
            busy: surface.lock.checking
            capsLock: surface.lock.caps.locked
            message: surface.lock.message
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.BlankCursor
    }
}
