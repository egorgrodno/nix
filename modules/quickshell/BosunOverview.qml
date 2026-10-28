pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell

// The bosun panel's small size, a dropdown under the bar's module: the fleet
// counted by state, with Pause all and the full panel; the decisions waiting
// on the user, each with Approve, Deny and Open; the fleet's rows; and the
// desk's latest line, with a line to tell it something. A row, or Open, opens
// the full panel on it. Tab takes the keyboard to the rows, where the
// movement keys move and Enter opens, and on to the field. Pause all takes a
// second click within three seconds, as in the full panel.
Item {
    id: overview

    // Where Panel.qml sends the keyboard from the field.
    readonly property Item keyboardHome: overview
    // The decisions shown as cards; the rest wait in the full panel.
    readonly property int cardSlots: 3
    readonly property var cards: Bosun.mine.slice(0, cardSlots)
    // What Tab and the movement keys step through, in order.
    readonly property var keys: [...cards.map(d => `decision:${d.id}`), ...Bosun.tree.map(s => `session:${s.node}`), ...(Bosun.connected ? ["desk"] : [])]
    // The row the keyboard is on, while it is in the rows.
    property string current: ""
    readonly property bool inRows: rowKeys.activeFocus
    property bool pauseArmed: false
    // What the ages count from.
    property real now: Date.now()
    // The most the overview may take, the work area's height.
    property real maxHeight: Infinity

    // The full panel on `key`.
    function open(key) {
        BosunKept.select(key);
        BosunKept.full = true;
    }

    function focusRows() {
        if (keys.length === 0)
            return;
        if (!keys.includes(current))
            current = keys[0];
        rowKeys.forceActiveFocus();
    }

    function move(step) {
        if (!inRows) {
            focusRows();
            return;
        }
        const from = keys.indexOf(current);
        current = keys[Math.max(0, Math.min(keys.length - 1, from + step))] ?? "";
    }

    // Scrolls the decisions and the fleet to `row`, one of theirs.
    function reveal(row) {
        const y = row.mapToItem(rows, 0, 0).y;
        middle.contentY = Math.max(0, Math.min(y, Math.max(middle.contentY, y + row.height - middle.height)));
    }

    function pause() {
        if (!pauseArmed) {
            pauseArmed = true;
            disarm.restart();
            return;
        }
        pauseArmed = false;
        Bosun.pause();
    }

    // What Bosun's IpcHandler asks of the panel, as BosunView answers it.
    // While paused, the button resumes at a click, with nothing to arm.

    function setSidebar() {
        return "the overview has no sidebar";
    }

    function focusAt(where) {
        if (where !== "list")
            return `no place ${where} in the overview`;
        focusRows();
        return "";
    }

    function armAction(action) {
        if (action !== "pause" || !Bosun.connected || Bosun.paused || Bosun.fleetOp !== "")
            return `${action} is not on offer here`;
        pauseArmed = false;
        pause();
        return "";
    }

    function panelState() {
        return {
            kind: "overview",
            focus: inRows ? "rows" : field.focused ? "field" : "",
            armed: pauseArmed ? "p" : ""
        };
    }

    function press(event) {
        pauseArmed = false;
        if (event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return false;
        switch (event.key) {
        case Qt.Key_Down:
            move(1);
            return true;
        case Qt.Key_Up:
            move(-1);
            return true;
        case Qt.Key_Tab:
        case Qt.Key_Backtab:
            if (inRows)
                field.focusIn();
            else
                focusRows();
            return true;
        case Qt.Key_Return:
        case Qt.Key_Enter:
            if (!inRows || current === "")
                return false;
            open(current);
            return true;
        }
        switch (event.text) {
        case Host.directions.down:
            move(1);
            return true;
        case Host.directions.up:
            move(-1);
            return true;
        case "f":
            BosunKept.full = true;
            return true;
        }
        return false;
    }

    implicitHeight: column.implicitHeight + 2 * column.y
    Keys.onPressed: event => event.accepted = press(event)
    Component.onCompleted: forceActiveFocus()

    Timer {
        running: true
        interval: 30000
        repeat: true
        onTriggered: overview.now = Date.now()
    }

    Timer {
        id: disarm

        interval: 3000
        onTriggered: overview.pauseArmed = false
    }

    // The rows' own keyboard.
    Item {
        id: rowKeys

        Keys.onPressed: event => event.accepted = overview.press(event)
    }

    Column {
        id: column

        x: 16
        y: 16
        width: parent.width - 2 * x
        spacing: 12

        Item {
            id: head

            width: parent.width
            height: 32

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    text: BosunLook.robot
                    color: Bosun.working ? Theme.blue : Theme.foregroundStrong
                    font.pixelSize: 18
                }

                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    rightPadding: 6
                    text: "bosun"
                    font.weight: Font.DemiBold
                }

                Repeater {
                    model: BosunLook.fleetCounts

                    BosunCount {
                        required property var modelData

                        stateKey: modelData.key
                        n: modelData.n
                    }
                }
            }

            Row {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                spacing: 8

                BosunIconButton {
                    visible: Bosun.connected
                    enabled: Bosun.fleetOp === ""
                    text: Bosun.paused ? BosunLook.play : BosunLook.pause
                    tip: Bosun.paused ? "Resume" : overview.pauseArmed ? "Click again to pause" : "Pause all"
                    lit: overview.pauseArmed
                    hoverFill: Theme.alpha(Theme.yellow, 0.5)
                    onClicked: Bosun.paused ? Bosun.unpause() : overview.pause()
                }

                BosunIconButton {
                    text: BosunLook.expand
                    tip: "Full panel"
                    onClicked: BosunKept.full = true
                }
            }
        }

        Rule {
            id: headRule
        }

        Caption {
            id: offline

            visible: !Bosun.connected
            text: "bosun watch reconnects once the daemon runs"
        }

        // The decisions and the fleet, which scroll once the overview would
        // outgrow the work area.
        Flickable {
            id: middle

            visible: Bosun.connected
            width: parent.width
            height: Math.min(contentHeight, overview.maxHeight - 2 * column.y - head.height - headRule.height - deskPart.implicitHeight - 3 * column.spacing)
            contentHeight: rows.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            ScrollBar.vertical: OverlayScrollBar {}

            Column {
                id: rows

                width: parent.width
                spacing: 12

                Section {
                    name: "Waiting on you"

                    BosunBadge {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        visible: Bosun.mine.length > 0
                        count: Bosun.mine.length
                    }
                }

                // In place of cards, so the header never looks like a button.
                Caption {
                    visible: Bosun.mine.length === 0
                    text: "Nothing waits on you"
                    color: Theme.foregroundFaint
                }

                Repeater {
                    model: ScriptModel {
                        values: overview.cards
                        objectProp: "id"
                    }

                    DecisionCard {}
                }

                BosunLink {
                    visible: Bosun.mine.length > overview.cardSlots
                    text: `${Bosun.mine.length - overview.cardSlots} more in the full panel  \u{203A}`
                    onClicked: overview.open(`decision:${Bosun.mine[overview.cardSlots].id}`)
                }

                Section {
                    visible: Bosun.tree.length > 0
                    name: "Fleet"
                }

                Column {
                    width: parent.width

                    Repeater {
                        model: ScriptModel {
                            values: Bosun.tree
                            objectProp: "node"
                        }

                        FleetRow {}
                    }
                }
            }
        }

        Column {
            id: deskPart

            width: parent.width
            spacing: column.spacing

            Section {
                visible: Bosun.connected
                name: "Desk"

                Row {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: BosunKept.deskUnread
                        width: 7
                        height: 7
                        radius: 3.5
                        color: Theme.blue
                    }

                    Caption {
                        text: BosunLook.age(desk.activity?.at, overview.now)
                    }
                }
            }

            // What the desk last said or does, which opens it.
            OverviewRow {
                id: desk

                readonly property var activity: (Bosun.desk ?? Bosun.master)?.activity ?? null

                key: "desk"
                visible: Bosun.connected
                height: deskText.implicitHeight + 8
                onTapped: overview.open("desk")

                BarText {
                    id: deskText

                    y: 4
                    width: parent.width
                    wrapMode: Text.Wrap
                    maximumLineCount: 4
                    elide: Text.ElideRight
                    lineHeight: 1.25
                    text: desk.activity ? BosunLook.activityText(desk.activity) : "Nothing from the desk yet"
                    color: desk.activity ? Theme.foregroundStrong : Theme.foregroundMuted
                    font.pixelSize: 14
                }
            }

            BosunComposer {
                id: field

                visible: Bosun.connected
                width: parent.width
                height: 38
                oneLine: true
                sendGlyph: true
                placeholder: Bosun.desk ? "Tell the desk…" : "Tell the master…"
                draftKey: "tell"
                onSent: text => Bosun.tell(text)
                onLeave: overview.forceActiveFocus()
            }

            Rule {}

            BosunHints {
                model: [
                    {
                        keys: ["f"],
                        text: "full panel"
                    },
                    {
                        keys: ["Tab"],
                        text: "rows"
                    },
                    {
                        keys: ["Esc"],
                        text: "close"
                    }
                ]
            }
        }
    }

    component Rule: Rectangle {
        width: parent?.width ?? 0
        height: 1
        color: Theme.tint(0.08)
    }

    // A section's name, and what the caller declares at its right.
    component Section: Item {
        id: section

        required property string name

        width: parent?.width ?? 0
        height: 20

        Caption {
            anchors.verticalCenter: parent.verticalCenter
            text: section.name
            font.pixelSize: 14
        }
    }

    // A row the keyboard steps to, named by its `key`, which a decision's
    // or a session's scrolls into view as it does.
    component OverviewRow: BosunRow {
        id: overviewRow

        property string key

        width: parent?.width ?? 0
        current: overview.current === key
        lit: current && overview.inRows
        focused: overview.inRows
        edgeOffset: -8
        onCurrentChanged: if (current && key !== "desk")
            overview.reveal(overviewRow)
    }

    // A decision on a dashed card: who asks and what, with Approve and Deny
    // for a permission, and Open, which opens it in the full panel.
    component DecisionCard: OverviewRow {
        id: card

        required property var modelData
        readonly property var decision: modelData
        readonly property string kind: Bosun.kindOf(decision)

        key: `decision:${decision.id}`
        height: body.implicitHeight + 24
        // Its buttons act; Open opens it.
        inert: true

        BosunDashed {
            radius: 6
        }

        Column {
            id: body

            x: 12
            y: 12
            width: parent.width - 24
            spacing: 10

            Item {
                width: parent.width
                height: who.implicitHeight

                Row {
                    id: who

                    width: parent.width - age.width - 8
                    spacing: 8
                    clip: true

                    BarText {
                        text: BosunLook.states.blocked.glyph
                        color: Theme.yellow
                        font.pixelSize: 15
                    }

                    BarText {
                        text: card.decision.node ?? ""
                        font.pixelSize: 15
                    }

                    BarText {
                        text: card.kind === "permission" ? card.decision.tool === "Bash" ? "wants to run" : `wants to use ${card.decision.tool}` : card.kind === "question" ? "asks" : "says"
                        color: Theme.foregroundMuted
                        font.pixelSize: 15
                    }
                }

                Caption {
                    id: age

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: BosunLook.age(Bosun.askedAt(card.decision), overview.now)
                }
            }

            Rectangle {
                width: parent.width
                height: summary.implicitHeight + 13
                radius: 4
                color: Theme.tint(0.05)

                BarText {
                    id: summary

                    x: 10
                    y: 7
                    width: parent.width - 20
                    elide: Text.ElideRight
                    wrapMode: card.kind === "permission" ? Text.NoWrap : Text.Wrap
                    maximumLineCount: card.kind === "permission" ? 1 : 3
                    text: Bosun.summaryOf(card.decision)
                    font.family: card.kind === "permission" ? Theme.fontMono : Theme.fontUI
                    font.pixelSize: 14
                }
            }

            Item {
                width: parent.width
                height: 30

                Row {
                    spacing: 8
                    visible: card.kind === "permission"

                    TextButton {
                        height: 30
                        text: `${BosunLook.check}  Approve`
                        fill: Theme.alpha(Theme.green, 0.16)
                        hoverFill: Theme.green
                        textColor: Theme.green
                        litTextColor: Theme.backgroundMain
                        onClicked: Bosun.approve(card.decision.id)
                    }

                    TextButton {
                        height: 30
                        text: `${BosunLook.close}  Deny`
                        fill: Theme.alpha(Theme.red, 0.16)
                        hoverFill: Theme.red
                        textColor: Theme.red
                        litTextColor: Theme.backgroundMain
                        onClicked: Bosun.deny(card.decision.id, "")
                    }
                }

                TextButton {
                    anchors.right: parent.right
                    height: 30
                    text: "Open  \u{203A}"
                    onClicked: overview.open(card.key)
                }
            }
        }
    }

    // A session, indented under its parent: its state, its name, what it last
    // did and how long ago.
    component FleetRow: OverviewRow {
        id: row

        required property var modelData
        readonly property var session: Bosun.sessions.find(s => s.node === modelData.node) ?? modelData
        readonly property string stateKey: BosunLook.stateOf(session)
        readonly property real indent: 12 * (session.depth ?? 0)

        key: `session:${modelData.node}`
        height: 34
        edgeOffset: 0
        onTapped: overview.open(key)

        BosunStateGlyph {
            x: 8 + row.indent
            anchors.verticalCenter: parent.verticalCenter
            stateKey: row.stateKey
            font.pixelSize: 15
        }

        BarText {
            id: nameText

            x: 32 + row.indent
            width: 142 - x
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: row.session.node
            font.pixelSize: 15
        }

        BosunActivityLine {
            anchors.left: parent.left
            anchors.leftMargin: 150
            anchors.right: ageText.left
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter
            visible: row.session.activity !== undefined
            activity: row.session.activity ?? null
            tint: row.stateKey === "working" ? Theme.blue : Theme.foregroundMuted
        }

        Caption {
            id: ageText

            anchors.right: parent.right
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            text: BosunLook.age(row.session.activity?.at, overview.now)
        }
    }
}
