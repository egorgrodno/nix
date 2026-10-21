import QtQuick
import Quickshell
import Quickshell.Widgets

// The wallpapers as a strip of thumbnails over the bottom bar, each at the
// screen's aspect and cropped as awww crops it, the one showing ringed and the
// one applied as the panel opened checked. Moving to one shows it at once
// behind the windows, awww's circle growing out of its tile. Enter, or a click
// on the ringed tile, keeps it; any other close sets back the applied one, the
// circle closing back into the tile it grew out of. Left and Right move, Page
// Up and Page Down by a strip's width, Home and End to either end; the wheel
// and a drag scroll without moving. Open folder opens the folder in pcmanfm,
// making it first if it is missing, as on a fresh install.
Panel {
    id: panel

    // Showing as the panel opened.
    property string original: ""
    property bool kept: false
    readonly property int tileWidth: 224
    readonly property int tileHeight: Math.round(tileWidth * (screen?.height ?? 9) / (screen?.width ?? 16))
    readonly property int gap: 8
    // As many tiles as fit between the outer gaps, and room for the footer.
    readonly property int columns: Math.max(2, Math.min(Wallpapers.count, Math.floor(((screen?.width ?? 0) - 2 * Theme.outerGap - 2 * padding + gap) / (tileWidth + gap))))

    function select(index) {
        index = Math.max(0, Math.min(Wallpapers.count - 1, index));
        if (Wallpapers.count === 0 || index === strip.currentIndex)
            return;
        strip.currentIndex = index;
        Wallpapers.show(Wallpapers.path(index), at(index));
    }

    function keep() {
        // Once, though a held key repeats while the panel fades.
        if (!open)
            return;
        if (strip.currentIndex >= 0) {
            kept = true;
            Wallpapers.keep(Wallpapers.path(strip.currentIndex));
        }
        close();
    }

    // The centre of a tile, scrolled into view, or of the strip, as fractions
    // of the screen with y from the bottom, as awww takes it.
    function at(index) {
        const item = (index >= 0 ? strip.itemAtIndex(index) : null) ?? strip;
        const centre = item.mapToItem(null, item.width / 2, item.height / 2);
        const fraction = v => Math.max(0, Math.min(0.99, v));
        return {
            x: fraction((margins.left + centre.x) / screen.width),
            y: fraction(1 - (margins.top + centre.y) / screen.height)
        };
    }

    upward: true
    padding: 12
    boxWidth: columns * (tileWidth + gap) - gap + 2 * padding

    onOpenChanged: {
        if (open)
            return;
        Wallpapers.picking = false;
        if (kept || original === "" || Wallpapers.shown === original)
            return;
        Wallpapers.show(original, at(strip.currentIndex), true);
    }
    Component.onCompleted: {
        Wallpapers.picking = true;
        Wallpapers.rescan();
        original = Wallpapers.shown;
        strip.currentIndex = Wallpapers.indexOf(original);
        strip.forceActiveFocus();
    }

    Column {
        width: panel.contentWidth
        spacing: 12

        Item {
            width: parent.width
            height: panel.tileHeight

            ListView {
                id: strip

                anchors.fill: parent
                orientation: ListView.Horizontal
                spacing: panel.gap
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                keyNavigationEnabled: false
                currentIndex: -1
                model: Wallpapers.present ? Wallpapers.files : null
                onCurrentIndexChanged: if (currentIndex >= 0)
                    positionViewAtIndex(currentIndex, ListView.Contain)
                Keys.onPressed: event => {
                    switch (event.key) {
                    case Qt.Key_Left:
                        panel.select(currentIndex - 1);
                        break;
                    case Qt.Key_Right:
                        panel.select(currentIndex + 1);
                        break;
                    case Qt.Key_PageUp:
                        panel.select(currentIndex - panel.columns);
                        break;
                    case Qt.Key_PageDown:
                        panel.select(currentIndex + panel.columns);
                        break;
                    case Qt.Key_Home:
                        panel.select(0);
                        break;
                    case Qt.Key_End:
                        panel.select(Wallpapers.count - 1);
                        break;
                    case Qt.Key_Return:
                    case Qt.Key_Enter:
                        panel.keep();
                        break;
                    default:
                        return;
                    }
                    event.accepted = true;
                }

                delegate: Item {
                    id: tile

                    required property int index
                    required property string filePath
                    required property url fileUrl
                    readonly property bool current: ListView.isCurrentItem

                    width: panel.tileWidth
                    height: panel.tileHeight

                    ClippingRectangle {
                        anchors.fill: parent
                        radius: Theme.radius - 4
                        color: Qt.rgba(1, 1, 1, 0.06)

                        Image {
                            anchors.fill: parent
                            source: tile.fileUrl
                            sourceSize.width: width
                            sourceSize.height: height
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }

                    Rectangle {
                        anchors.fill: parent
                        radius: Theme.radius - 4
                        color: "transparent"
                        border.width: tile.current ? 2 : 1
                        border.color: tile.current ? Theme.blue : mouse.containsMouse ? Qt.rgba(1, 1, 1, 0.35) : Qt.rgba(1, 1, 1, 0.1)
                    }

                    // The one applied, which a close without keeping sets back.
                    Rectangle {
                        anchors.top: parent.top
                        anchors.right: parent.right
                        anchors.margins: 6
                        visible: tile.filePath === panel.original
                        width: 22
                        height: 22
                        radius: 11
                        color: Theme.alpha(Theme.backgroundMain, 0.85)

                        BarText {
                            anchors.centerIn: parent
                            text: "\u{F012C}"
                            font.pixelSize: 14
                        }
                    }

                    MouseArea {
                        id: mouse

                        anchors.fill: parent
                        hoverEnabled: true
                        onClicked: tile.current ? panel.keep() : panel.select(tile.index)
                    }
                }
            }

            // Over the strip, taking only the wheel, so clicks and drags reach
            // the tiles. Either wheel, a notch a tile: a horizontal strip
            // ignores the vertical one by itself.
            MouseArea {
                anchors.fill: strip
                acceptedButtons: Qt.NoButton
                onWheel: wheel => {
                    const notches = (wheel.angleDelta.x || wheel.angleDelta.y) / 120;
                    const from = scroll.running ? scroll.to : strip.contentX;
                    const end = strip.originX + strip.contentWidth - strip.width;
                    scroll.to = Math.max(strip.originX, Math.min(end, from - notches * (panel.tileWidth + panel.gap)));
                    scroll.restart();
                }

                NumberAnimation {
                    id: scroll

                    target: strip
                    property: "contentX"
                    duration: 200
                    easing.type: Easing.OutExpo
                }
            }

            Caption {
                anchors.centerIn: parent
                visible: Wallpapers.count === 0
                text: `No wallpapers in ${Wallpapers.folder.replace(Quickshell.env("HOME"), "~")}`
            }
        }

        Item {
            width: parent.width
            height: folderButton.height

            Caption {
                anchors.verticalCenter: parent.verticalCenter
                visible: Wallpapers.count > 0
                text: "Left Right preview · Enter keep · Escape revert"
            }

            TextButton {
                id: folderButton

                anchors.right: parent.right
                text: "Open folder"
                onClicked: {
                    panel.close();
                    Wallpapers.openFolder();
                }
            }
        }
    }
}
