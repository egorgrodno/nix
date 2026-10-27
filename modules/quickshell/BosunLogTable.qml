pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell

// The expanded panel's Log: every entry the daemon keeps, newest first, as a
// table of when, who and what, with the link to what each names. Filtered by
// kind, by session and by text. the movement keys move through the rows and Enter opens
// what the selected one names.
Item {
    id: table

    // Where Panel.qml sends the keyboard from the filter field.
    readonly property Item keyboardHome: table
    // The selected entry's seq, or -1.
    property int selectedSeq: -1
    // The filters, which BosunKept keeps: "all", "decisions", "messages",
    // "sessions" or "yours"; the session the entries are about, or "" for any;
    // and text.
    readonly property string kind: BosunKept.logKind
    readonly property string session: BosunKept.logSession
    readonly property string text: BosunKept.logText
    // Lights the selected row's edge while the keyboard is here.
    readonly property bool focused: activeFocus
    property bool scrollRestored: false
    readonly property var rows: {
        const words = text.trim().toLowerCase();
        return Bosun.log.filter(e => {
            if (kind === "yours" ? e.by !== "user" : kind !== "all" && BosunLook.logGroup(e) !== kind)
                return false;
            if (session !== "" && !BosunLook.logSessions(e).includes(session))
                return false;
            return words === "" || `${BosunLook.logWho(e)} ${BosunLook.logWhat(e)}`.toLowerCase().includes(words);
        }).reverse();
    }
    readonly property int today: {
        const day = new Date().toDateString();
        return Bosun.log.filter(e => e.at && new Date(e.at).toDateString() === day).length;
    }
    // Every session the log names, then those in the fleet it does not.
    readonly property var sessions: {
        const names = new Set();
        for (const e of Bosun.log)
            for (const node of BosunLook.logSessions(e))
                names.add(node);
        for (const s of Bosun.sessions)
            names.add(s.node);
        return [...names].sort();
    }

    // A row picked, by click or by the movement keys.
    signal chosen(var entry)
    // A link followed: the key to select and what to hold for it.
    signal opened(string key, var item)

    function move(step) {
        if (rows.length === 0)
            return;
        const from = rows.findIndex(e => e.seq === selectedSeq);
        chosen(rows[from < 0 ? 0 : Math.max(0, Math.min(rows.length - 1, from + step))]);
    }

    function openNamed() {
        const link = BosunLook.logLink(rows.find(e => e.seq === selectedSeq) ?? {});
        if (link)
            opened(link.key, link.item);
    }

    // Until the scroll is restored, it is not kept.
    function restoreScroll() {
        scrollRestored = false;
        restoring.restart();
    }

    clip: true
    onVisibleChanged: {
        if (visible)
            restoreScroll();
        else
            scrollRestored = false;
    }
    Component.onCompleted: if (visible)
        restoreScroll()
    onSelectedSeqChanged: revealing.restart()

    // Once the rows have laid out. Timers rather than Qt.callLater, which
    // outlives the table.
    Timer {
        id: revealing

        interval: 0
        onTriggered: {
            const index = table.rows.findIndex(e => e.seq === table.selectedSeq);
            if (index >= 0)
                list.positionViewAtIndex(index, ListView.Contain);
        }
    }

    Timer {
        id: restoring

        interval: 0
        onTriggered: {
            const kept = BosunKept.scroll("log") ?? list.contentY;
            list.contentY = Math.max(list.originY, Math.min(kept, list.originY + list.contentHeight - list.height));
            table.scrollRestored = true;
        }
    }

    // The title, and the filters beside it. Once the field there would be
    // narrower than 160, the field stays beside the title and the chips and
    // the session go under it.
    Item {
        id: header

        // Beside the title, what the filters leave for the field.
        readonly property real beside: width - todayText.x - todayText.width - 24
        readonly property real room: beside - filters.width - filters.spacing
        readonly property bool wraps: room < 160

        x: 28
        y: 18
        width: parent.width - 2 * x
        height: wraps ? 66 : 28
        clip: true

        BarText {
            id: title

            y: (28 - height) / 2
            text: "Log"
            font.pixelSize: 20
            font.weight: Font.DemiBold
        }

        Caption {
            id: todayText

            anchors.left: title.right
            anchors.leftMargin: 12
            anchors.baseline: title.baseline
            text: `${table.today} ${table.today === 1 ? "event" : "events"} today`
        }

        Row {
            id: filters

            anchors.right: header.wraps ? parent.right : field.left
            anchors.rightMargin: header.wraps ? 0 : spacing
            y: header.wraps ? 38 : 0
            height: 28
            spacing: 10

            Row {
                id: chips

                anchors.verticalCenter: parent.verticalCenter
                spacing: 2

                Repeater {
                    model: [
                        {
                            key: "all",
                            text: "All"
                        },
                        {
                            key: "decisions",
                            text: "Decisions"
                        },
                        {
                            key: "messages",
                            text: "Messages"
                        },
                        {
                            key: "sessions",
                            text: "Sessions"
                        },
                        {
                            key: "yours",
                            text: "Yours"
                        }
                    ]

                    TextButton {
                        required property var modelData

                        height: 26
                        text: modelData.text
                        lit: table.kind === modelData.key
                        hoverFill: lit ? Theme.blue : Theme.tint(0.12)
                        textColor: lit ? Theme.backgroundMain : Theme.foregroundStrong
                        onClicked: BosunKept.logKind = modelData.key
                    }
                }
            }

            TextButton {
                id: sessionButton

                anchors.verticalCenter: parent.verticalCenter
                // At most 180, so a long session name cannot push the row
                // past the header.
                width: Math.min(180, sessionName.implicitWidth + 8 + sessionChevron.implicitWidth + 20)
                height: 26
                lit: picker.visible
                onClicked: {
                    const at = mapToItem(table, 0, height + 4);
                    picker.x = Math.min(at.x, table.width - picker.width - 12);
                    picker.y = at.y;
                    picker.visible = !picker.visible;
                }

                BarText {
                    id: sessionName

                    x: 10
                    width: sessionChevron.x - 8 - x
                    anchors.verticalCenter: parent.verticalCenter
                    elide: Text.ElideRight
                    text: table.session || "Any session"
                    font.pixelSize: 14
                }

                BarText {
                    id: sessionChevron

                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: BosunLook.chevronDown
                    font.pixelSize: 14
                }
            }
        }

        Rectangle {
            id: field

            anchors.right: parent.right
            width: Math.max(120, Math.min(260, header.wraps ? header.beside : header.room))
            height: 28
            radius: Theme.radius - 4
            color: Theme.tint(0.06)
            border.width: 1
            border.color: filterInput.activeFocus ? Theme.blue : Theme.tint(0.12)

            BarText {
                id: filterGlyph

                x: 10
                anchors.verticalCenter: parent.verticalCenter
                text: BosunLook.filter
                color: Theme.foregroundMuted
                font.pixelSize: 14
            }

            TextInput {
                id: filterInput

                anchors.left: filterGlyph.right
                anchors.leftMargin: 8
                anchors.right: parent.right
                anchors.rightMargin: 10
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                text: table.text
                color: Theme.foregroundStrong
                selectionColor: Theme.blue
                selectByMouse: true
                font.family: Theme.fontUI
                font.pixelSize: 13
                font.hintingPreference: Font.PreferFullHinting
                renderType: Text.CurveRendering
                onTextEdited: BosunKept.logText = text
                Keys.onReturnPressed: table.forceActiveFocus()
                Keys.onEnterPressed: table.forceActiveFocus()
                Keys.onTabPressed: table.forceActiveFocus()
                Keys.onEscapePressed: table.forceActiveFocus()

                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: filterInput.text === ""
                    text: "Filter the log"
                    color: Theme.foregroundMuted
                    font.pixelSize: 13
                }
            }
        }
    }

    // The table's columns, shared by the heading and the rows.
    QtObject {
        id: columns

        readonly property real time: 12
        readonly property real glyph: 64
        readonly property real who: 92
        readonly property real what: 304
    }

    Item {
        id: heading

        x: 28
        anchors.top: header.bottom
        anchors.topMargin: 18
        width: parent.width - 2 * x
        height: 26

        Caption {
            x: columns.time
            anchors.verticalCenter: parent.verticalCenter
            text: "Time"
            font.pixelSize: 12
        }

        Caption {
            x: columns.who
            anchors.verticalCenter: parent.verticalCenter
            text: "Who"
            font.pixelSize: 12
        }

        Caption {
            x: columns.what
            anchors.verticalCenter: parent.verticalCenter
            text: "What"
            font.pixelSize: 12
        }

        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width
            height: 1
            color: Theme.tint(0.08)
        }
    }

    ListView {
        id: list

        x: 28
        anchors.top: heading.bottom
        anchors.bottom: hints.top
        anchors.bottomMargin: 12
        width: parent.width - 2 * x
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        onContentYChanged: if (table.scrollRestored)
            BosunKept.keepScroll("log", contentY)
        model: ScriptModel {
            values: table.rows
            objectProp: "seq"
        }

        ScrollBar.vertical: OverlayScrollBar {}

        delegate: EntryRow {}
    }

    // Takes the view back to the newest entry, at the top, clear of the
    // scroll bar.
    BosunJumpButton {
        x: list.x + list.width - width - 20
        y: list.y + 12
        glyph: BosunLook.arrowUp
        shown: !list.atYBeginning
        onClicked: top.restart()
    }

    NumberAnimation {
        id: top

        target: list
        property: "contentY"
        to: list.originY
        duration: 200
        easing.type: Easing.OutCubic
    }

    Caption {
        anchors.horizontalCenter: list.horizontalCenter
        y: list.y + 24
        visible: table.rows.length === 0
        text: Bosun.log.length === 0 ? "Nothing logged yet" : "No entry matches"
    }

    BosunHints {
        id: hints

        x: 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        model: [
            {
                keys: ["Esc"],
                text: "back to the normal size"
            },
            {
                keys: [Host.directions.down, Host.directions.up],
                text: "move"
            },
            {
                keys: ["Enter"],
                text: "open what it names"
            }
        ]
    }

    // Closes the session list at a press anywhere else in the table.
    MouseArea {
        anchors.fill: parent
        visible: picker.visible
        onPressed: picker.visible = false
    }

    // The sessions the filter can pick, under its button.
    Rectangle {
        id: picker

        width: 220
        height: Math.min(pickList.contentHeight + 12, table.height - y - 20)
        visible: false
        radius: Theme.radius - 4
        color: Theme.backgroundRaised
        border.width: 1
        border.color: Theme.tint(0.12)

        ListView {
            id: pickList

            anchors.fill: parent
            anchors.margins: 6
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            model: [""].concat(table.sessions)

            ScrollBar.vertical: OverlayScrollBar {}

            delegate: Rectangle {
                id: choice

                required property string modelData

                width: ListView.view.width
                height: 28
                radius: Theme.radius - 6
                color: choiceHover.hovered ? Theme.tint(0.08) : table.session === modelData ? Theme.tint(0.05) : "transparent"

                BarText {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 2 * x
                    elide: Text.ElideRight
                    text: choice.modelData || "Any session"
                    color: table.session === choice.modelData ? Theme.foregroundStrong : Theme.foregroundMuted
                    font.pixelSize: 13
                }

                HoverHandler {
                    id: choiceHover
                }

                TapHandler {
                    onTapped: {
                        BosunKept.logSession = choice.modelData;
                        picker.visible = false;
                    }
                }
            }
        }
    }

    // An entry: its time, its glyph, who acted, what happened, and the link
    // to what it names.
    component EntryRow: Item {
        id: row

        required property var modelData
        readonly property var entry: modelData
        readonly property bool current: entry.seq === table.selectedSeq
        readonly property var link: BosunLook.logLink(entry)

        width: ListView.view.width
        height: 36

        Rectangle {
            anchors.fill: parent
            radius: Theme.radius - 4
            color: row.current ? Theme.tint(0.07) : rowHover.hovered ? Theme.tint(0.04) : "transparent"

            Rectangle {
                width: 2
                height: parent.height
                visible: row.current
                color: table.focused ? Theme.blue : Theme.foregroundFaint
            }
        }

        BarText {
            x: columns.time
            anchors.verticalCenter: parent.verticalCenter
            text: BosunLook.timeOf(row.entry)
            color: Theme.foregroundMuted
            font.family: Theme.fontMono
            font.pixelSize: 12
        }

        BarText {
            x: columns.glyph
            anchors.verticalCenter: parent.verticalCenter
            text: BosunLook.logGlyph(row.entry)
            color: BosunLook.logColor(row.entry)
            font.pixelSize: 14
        }

        BarText {
            x: columns.who
            width: columns.what - columns.who - 12
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: BosunLook.logWho(row.entry)
            font.pixelSize: 13
        }

        BarText {
            x: columns.what
            width: (linkText.visible ? linkText.x : parent.width) - 12 - x
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: BosunLook.logWhat(row.entry)
            font.pixelSize: 13
        }

        HoverHandler {
            id: rowHover
        }

        TapHandler {
            onTapped: {
                if (linkHover.hovered)
                    return;
                table.chosen(row.entry);
                table.forceActiveFocus();
            }
        }

        BarText {
            id: linkText

            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: row.link !== null
            text: row.link?.text ?? ""
            color: linkHover.hovered ? Theme.foregroundStrong : Theme.blue
            font.pixelSize: 13

            HoverHandler {
                id: linkHover

                cursorShape: Qt.PointingHandCursor
            }

            TapHandler {
                onTapped: table.opened(row.link.key, row.link.item)
            }
        }
    }
}
