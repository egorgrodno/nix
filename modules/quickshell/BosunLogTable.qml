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

                    ChoiceButton {
                        required property var modelData

                        height: 26
                        text: modelData.text
                        lit: table.kind === modelData.key
                        onClicked: BosunKept.logKind = modelData.key
                    }
                }
            }

            BosunDropdown {
                anchors.verticalCenter: parent.verticalCenter
                // At most 180, so a long session name cannot push the row
                // past the header.
                maxWidth: 180
                menuWidth: 220
                values: table.sessions
                current: table.session
                fallback: "Any session"
                resettable: true
                onPicked: value => BosunKept.logSession = value
            }
        }

        BosunComposer {
            id: field

            anchors.right: parent.right
            width: Math.max(120, Math.min(260, header.wraps ? header.beside : header.room))
            height: 28
            oneLine: true
            sends: false
            leadGlyph: BosunLook.filter
            placeholder: "Filter the log"
            text: table.text
            onTextChanged: BosunKept.logText = text
            onAccepted: table.forceActiveFocus()
            onLeave: table.forceActiveFocus()
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

    // An entry: its time, its glyph, who acted, what happened, and the link
    // to what it names.
    component EntryRow: BosunRow {
        id: row

        required property var modelData
        readonly property var entry: modelData
        readonly property var link: BosunLook.logLink(entry)

        current: entry.seq === table.selectedSeq
        focused: table.focused
        width: ListView.view.width
        height: 36
        onTapped: {
            if (linkText.hovered)
                return;
            table.chosen(entry);
            table.forceActiveFocus();
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

        BosunLink {
            id: linkText

            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: row.link !== null
            text: row.link?.text ?? ""
            font.pixelSize: 13
            onClicked: table.opened(row.link.key, row.link.item)
        }
    }
}
