import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

// Over the apps module: a tab per mode, a search field, and the mode's rows,
// the selected one lit. Enter runs it: an app or one of its actions launches,
// a clipboard entry or a symbol is copied. Up and Down move the selection, Tab
// and Shift Tab change the mode, Right opens an app's actions and Left closes
// them, and Shift Delete forgets a clipboard entry. The list keeps its height
// as the rows filter, so the field never moves.
Panel {
    id: panel

    property string mode: "apps"
    // The row whose actions show, by its index among the mode's rows.
    property int expanded: -1
    readonly property int rowHeight: 40
    readonly property int visibleRows: 9
    readonly property var current: Launcher.modes.find(m => m.id === mode)
    readonly property var base: {
        switch (mode) {
        case "clipboard":
            return Clipboard.search(field.text);
        case "symbols":
            return Symbols.search(field.text);
        default:
            return Launcher.apps(field.text);
        }
    }
    readonly property var rows: {
        const row = base[expanded];
        if (!row?.actions?.length)
            return base;
        const actions = row.actions.map(a => ({
                    kind: "action",
                    entry: row.entry,
                    action: a
                }));
        return [...base.slice(0, expanded + 1), ...actions, ...base.slice(expanded + 1)];
    }
    readonly property var selected: rows[list.currentIndex] ?? null
    // Where the pointer last moved, so a row scrolled under a still pointer is
    // not selected.
    property point pointer

    function activate(row) {
        // Once, though a held key repeats while the panel fades.
        if (!open || !row)
            return;
        close();
        if (row.kind === "app")
            Launcher.launch(row.entry, null);
        else if (row.kind === "action")
            Launcher.launch(row.entry, row.action);
        else if (row.kind === "clip")
            Clipboard.copy(row.entry);
        else if (row.kind === "symbol")
            Symbols.copy(row.symbol);
    }

    // To the nearest row past any header, in the direction of travel, staying
    // put at either end.
    function select(target, direction) {
        target = Math.max(0, Math.min(rows.length - 1, target));
        while (rows[target]?.kind === "header")
            target += direction;
        if (target >= 0 && target < rows.length)
            list.currentIndex = target;
    }

    function cycle(step) {
        const modes = Launcher.modes;
        mode = modes[(modes.indexOf(current) + step + modes.length) % modes.length].id;
    }

    function expand(index) {
        expanded = index;
        select(index + 1, 1);
    }

    function collapse() {
        const app = expanded;
        expanded = -1;
        list.currentIndex = app;
    }

    function forget(row) {
        const index = list.currentIndex;
        Clipboard.remove(row.entry);
        select(index, -1);
    }

    boxWidth: 440
    // With the rows' own 8 px inset, their text sits 20 px in, as any panel's
    // content does.
    padding: 12

    onModeChanged: {
        field.text = "";
        if (mode === "clipboard")
            Clipboard.refresh();
    }
    onBaseChanged: expanded = -1
    Component.onCompleted: {
        if (mode === "clipboard")
            Clipboard.refresh();
        field.forceActiveFocus();
    }

    // The screen dimmed behind it, easing as the box fades, so both start
    // either way at once. Beneath the popups and the panels by a layer rule,
    // and taking no input, so a click outside still reaches the focus grab.
    PanelWindow {
        screen: panel.screen
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        exclusionMode: ExclusionMode.Ignore
        color: "transparent"
        mask: Region {}
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "quickshell-dim"

        Rectangle {
            anchors.fill: parent
            color: "black"
            opacity: panel.open ? 0.4 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: 200
                    easing.type: Easing.OutExpo
                }
            }
        }
    }

    Column {
        width: panel.contentWidth
        spacing: 12

        Row {
            x: 8
            spacing: 6

            Repeater {
                model: Launcher.modes

                TextButton {
                    required property var modelData

                    text: modelData.label
                    lit: panel.mode === modelData.id
                    onClicked: panel.mode = modelData.id
                }
            }
        }

        TextField {
            id: field

            x: 8
            width: parent.width - 16
            height: 36
            leftPadding: 36
            rightPadding: 10
            topPadding: 0
            bottomPadding: 0
            verticalAlignment: TextInput.AlignVCenter
            placeholderText: panel.current.placeholder
            placeholderTextColor: Theme.foregroundMuted
            color: "#ffffff"
            selectionColor: Theme.blue
            selectedTextColor: Theme.backgroundMain
            font.family: Theme.fontUI
            font.pixelSize: 15
            Keys.onPressed: event => {
                const row = panel.selected;
                const shift = (event.modifiers & Qt.ShiftModifier) !== 0;
                switch (event.key) {
                case Qt.Key_Down:
                    panel.select(list.currentIndex + 1, 1);
                    break;
                case Qt.Key_Up:
                    panel.select(list.currentIndex - 1, -1);
                    break;
                case Qt.Key_PageDown:
                    panel.select(list.currentIndex + panel.visibleRows, 1);
                    break;
                case Qt.Key_PageUp:
                    panel.select(list.currentIndex - panel.visibleRows, -1);
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    panel.activate(row);
                    break;
                case Qt.Key_Tab:
                    panel.cycle(1);
                    break;
                case Qt.Key_Backtab:
                    panel.cycle(-1);
                    break;
                case Qt.Key_Escape:
                    panel.close();
                    break;
                case Qt.Key_Right:
                    if (row?.kind !== "app" || !row.actions.length || panel.expanded === list.currentIndex)
                        return;
                    panel.expand(list.currentIndex);
                    break;
                case Qt.Key_Left:
                    if (panel.expanded < 0)
                        return;
                    panel.collapse();
                    break;
                case Qt.Key_Delete:
                    if (!shift || row?.kind !== "clip")
                        return;
                    panel.forget(row);
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }

            background: Rectangle {
                radius: Theme.radius - 4
                color: Qt.rgba(1, 1, 1, 0.06)
                border.width: 1
                border.color: field.activeFocus ? Theme.blue : Qt.rgba(1, 1, 1, 0.12)
            }

            BarText {
                x: 12
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{F0349}"
                color: Theme.foregroundMuted
                font.pixelSize: 16
            }
        }

        Item {
            width: parent.width
            height: panel.visibleRows * panel.rowHeight

            ListView {
                id: list

                anchors.fill: parent
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: panel.rows
                // New rows start at the first, which expanding, collapsing and
                // forgetting then move from.
                onModelChanged: panel.select(0, 1)
                // With the header over it in view too, which the selection
                // never lands on.
                onCurrentIndexChanged: {
                    if (panel.rows[currentIndex - 1]?.kind === "header")
                        positionViewAtIndex(currentIndex - 1, ListView.Contain);
                    positionViewAtIndex(currentIndex, ListView.Contain);
                }

                delegate: Item {
                    id: row

                    required property var modelData
                    required property int index
                    readonly property bool header: modelData.kind === "header"
                    readonly property bool current: ListView.isCurrentItem

                    width: list.width
                    height: header ? 32 : panel.rowHeight

                    Rectangle {
                        anchors.fill: parent
                        visible: !row.header
                        radius: Theme.radius - 4
                        color: row.current ? Qt.rgba(1, 1, 1, 0.07) : "transparent"
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: !row.header
                        hoverEnabled: true
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onPositionChanged: mouse => {
                            const at = mapToGlobal(mouse.x, mouse.y);
                            if (at.x !== panel.pointer.x || at.y !== panel.pointer.y) {
                                panel.pointer = at;
                                list.currentIndex = row.index;
                            }
                        }
                        onClicked: mouse => {
                            if (mouse.button === Qt.LeftButton)
                                panel.activate(row.modelData);
                            else if (row.modelData.kind === "app" && row.modelData.actions.length) {
                                if (panel.expanded === row.index)
                                    panel.collapse();
                                else
                                    panel.expand(row.index);
                            }
                        }
                    }

                    Loader {
                        anchors.fill: parent
                        sourceComponent: {
                            switch (row.modelData.kind) {
                            case "header":
                                return headerRow;
                            case "app":
                                return appRow;
                            case "action":
                                return actionRow;
                            case "clip":
                                return row.modelData.entry.image ? imageRow : textRow;
                            default:
                                return symbolRow;
                            }
                        }

                        // Each row component reads the delegate's data.
                        property var modelData: row.modelData
                        property bool expanded: panel.expanded === row.index
                    }
                }
            }

            Caption {
                anchors.centerIn: parent
                visible: list.count === 0
                text: panel.mode === "clipboard" && Clipboard.entries.length === 0 ? "The clipboard history is empty" : "No matches"
            }
        }

        Caption {
            x: 8
            text: panel.current.hint
        }
    }

    // Each sits in the Loader, whose modelData and expanded it reads.
    component Leading: Item {
        x: 8
        width: 28
        height: parent.height
    }

    Component {
        id: headerRow

        // In an item, as the Loader sizes what it loads to the row.
        Item {
            readonly property string title: parent.modelData.title

            Caption {
                x: 8
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 6
                text: title
            }
        }
    }

    Component {
        id: appRow

        Item {
            readonly property var entry: parent.modelData.entry
            readonly property bool expanded: parent.expanded

            Leading {
                id: icon

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: 24
                    source: entry.icon.startsWith("/") ? `file://${entry.icon}` : Quickshell.iconPath(entry.icon, "application-x-executable")
                }
            }

            BarText {
                id: name

                anchors.left: icon.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - x - more.width - 16)
                elide: Text.ElideRight
                text: entry.name
            }

            BarText {
                anchors.left: name.right
                anchors.leftMargin: 8
                anchors.right: more.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: entry.genericName
                color: Theme.foregroundMuted
                font.pixelSize: 14
            }

            // An app with actions, which Right opens.
            BarText {
                id: more

                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                visible: entry.actions.length > 0
                text: expanded ? "\u{F0140}" : "\u{F0142}"
                color: Theme.foregroundMuted
            }
        }
    }

    Component {
        id: actionRow

        Item {
            readonly property var action: parent.modelData.action

            BarText {
                anchors.left: parent.left
                anchors.leftMargin: 8 + 28 + 10
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: action.name
                font.pixelSize: 15
            }
        }
    }

    Component {
        id: textRow

        Item {
            readonly property var entry: parent.modelData.entry

            BarText {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: entry.text
                font.pixelSize: 15
            }
        }
    }

    Component {
        id: imageRow

        Item {
            readonly property var entry: parent.modelData.entry

            Component.onCompleted: Clipboard.decode(entry)

            Image {
                id: thumbnail

                x: 8
                anchors.verticalCenter: parent.verticalCenter
                width: 56
                height: 32
                fillMode: Image.PreserveAspectFit
                horizontalAlignment: Image.AlignLeft
                asynchronous: true
                sourceSize.height: 64
                source: Clipboard.thumbnails[entry.id] ? `file://${Clipboard.thumbnails[entry.id]}` : ""
            }

            BarText {
                id: format

                anchors.left: thumbnail.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: `${entry.image.format.toUpperCase()} ${entry.image.width}×${entry.image.height}`
                font.pixelSize: 15
            }

            BarText {
                anchors.left: format.right
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: entry.image.size
                color: Theme.foregroundMuted
                font.pixelSize: 14
            }
        }
    }

    Component {
        id: symbolRow

        Item {
            readonly property var symbol: parent.modelData.symbol

            Leading {
                id: glyph

                BarText {
                    anchors.centerIn: parent
                    text: symbol.char
                    font.family: Theme.fontMono
                    font.pixelSize: 22
                }
            }

            BarText {
                id: name

                anchors.left: glyph.right
                anchors.leftMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, parent.width - x - group.implicitWidth - 18)
                elide: Text.ElideRight
                text: symbol.name
            }

            BarText {
                id: group

                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                text: symbol.group
                color: Theme.foregroundMuted
                font.pixelSize: 14
            }
        }
    }
}
