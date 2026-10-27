pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell

// Waiting on you, Desk, Fleet and the latest three Log entries, as one list
// that the movement keys move through. Each row is a key: "decision:<id>", "desk",
// "session:<node>" or "log:<seq>". A row reads its session or decision from
// Bosun by that key, so a row kept across an update shows the update.
Item {
    id: sidebar

    // The selected row's key.
    property string selected
    // The selected decision once it no longer waits on the user, which its
    // row keeps showing until the selection moves.
    property var held: null
    // While the panel fills the work area, where the Log has its own table.
    property bool expanded: false
    // Lights the selected row's edge while the keyboard is here.
    readonly property bool focused: activeFocus
    property bool scrollRestored: false
    // What the rows' ages count from.
    property real now: Date.now()
    readonly property var waiting: {
        const mine = Bosun.mine;
        if (!held || mine.some(d => d.id === held.id))
            return mine;
        return [...mine, held].sort((a, b) => Number(a.id) - Number(b.id));
    }
    // The master and its workers, depth first, each session under its parent,
    // as `bosun status` prints it.
    readonly property var tree: {
        const children = new Map();
        for (const s of Bosun.sessions.filter(s => s.node !== "desk")) {
            const parent = s.parent ?? "";
            children.set(parent, [...(children.get(parent) ?? []), s]);
        }
        const rows = [];
        const walk = parent => {
            for (const s of children.get(parent) ?? []) {
                rows.push(s);
                walk(s.node);
            }
        };
        walk("");
        return rows;
    }
    readonly property var rows: {
        if (!Bosun.connected)
            return [
                {
                    key: "head:none",
                    type: "none"
                }
            ];
        const head = name => ({
                    key: `head:${name}`,
                    type: "head",
                    name: name
                });
        const rows = [head("Waiting on you")];
        for (const d of waiting)
            rows.push({
                key: `decision:${d.id}`,
                type: "decision",
                id: d.id
            });
        rows.push(head("Desk"), {
            key: "desk",
            type: "desk"
        }, head("Fleet"));
        for (const s of tree)
            rows.push({
                key: `session:${s.node}`,
                type: "session",
                node: s.node
            });
        const latest = Bosun.log.slice(-3).reverse();
        if (latest.length > 0)
            rows.push(head("Log"));
        for (const e of latest)
            rows.push({
                key: `log:${e.seq}`,
                type: "log",
                entry: e
            });
        return rows;
    }
    // What the movement keys step through, in order.
    readonly property var keys: rows.filter(r => !["head", "none"].includes(r.type)).map(r => r.key)

    signal chosen(string key)
    // The Log header's expand glyph, which expands the panel onto the Log.
    signal logExpanded

    function reveal(key) {
        const index = rows.findIndex(r => r.key === key);
        if (index >= 0)
            list.positionViewAtIndex(index, ListView.Contain);
    }

    // Until the scroll is restored, it is not kept.
    function restoreScroll() {
        scrollRestored = false;
        restoring.restart();
    }

    // The selection moves from outside too, as a notification's click does,
    // even while the panel closes.
    onSelectedChanged: revealing.restart()
    onVisibleChanged: {
        if (visible)
            restoreScroll();
        else
            scrollRestored = false;
    }
    Component.onCompleted: if (visible)
        restoreScroll()

    // Once the rows have laid out. Timers rather than Qt.callLater, which
    // outlives the sidebar.
    Timer {
        id: revealing

        interval: 0
        onTriggered: sidebar.reveal(sidebar.selected)
    }

    // Ticks the rows' ages.
    Timer {
        running: sidebar.visible
        interval: 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: sidebar.now = Date.now()
    }

    Timer {
        id: restoring

        interval: 0
        onTriggered: {
            const kept = BosunKept.scroll("sidebar") ?? list.contentY;
            list.contentY = Math.max(list.originY, Math.min(kept, list.originY + list.contentHeight - list.height));
            sidebar.scrollRestored = true;
        }
    }

    ListView {
        id: list

        anchors.fill: parent
        anchors.topMargin: 8
        anchors.bottomMargin: 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        onContentYChanged: if (sidebar.scrollRestored)
            BosunKept.keepScroll("sidebar", contentY)
        model: ScriptModel {
            values: sidebar.rows
            objectProp: "key"
        }

        ScrollBar.vertical: BosunScrollBar {}

        delegate: Loader {
            id: slot

            required property var modelData

            width: ListView.view.width
            sourceComponent: {
                switch (modelData.type) {
                case "head":
                    return header;
                case "decision":
                    return decisionRow;
                case "desk":
                    return deskRow;
                case "session":
                    return sessionRow;
                case "log":
                    return logRow;
                }
                return none;
            }

            Component {
                id: header

                Header {
                    name: slot.modelData.name
                }
            }

            Component {
                id: decisionRow

                DecisionRow {
                    rowKey: slot.modelData.key
                    decisionId: slot.modelData.id
                }
            }

            Component {
                id: deskRow

                DeskRow {
                    rowKey: slot.modelData.key
                }
            }

            Component {
                id: sessionRow

                SessionRow {
                    rowKey: slot.modelData.key
                    node: slot.modelData.node
                }
            }

            Component {
                id: logRow

                LogRow {
                    rowKey: slot.modelData.key
                    entry: slot.modelData.entry
                }
            }

            Component {
                id: none

                Caption {
                    leftPadding: 20
                    topPadding: 12
                    text: "The bosun daemon is not running"
                }
            }
        }
    }

    // A section's name, and for Waiting on you how many wait, yellow while any
    // does. The Log's has a glyph that expands the panel onto it.
    component Header: Item {
        id: head

        required property string name
        readonly property bool waiting: name === "Waiting on you"
        readonly property int count: Bosun.mine.length

        height: head.name === "Waiting on you" ? 32 : 44

        Caption {
            id: headText

            x: 20
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 6
            text: head.name
            color: head.waiting && head.count > 0 ? Theme.yellow : Theme.foregroundMuted
        }

        Caption {
            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.baseline: headText.baseline
            visible: head.waiting
            text: `${head.count}`
            color: headText.color
        }

        BarText {
            id: expandGlyph

            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: headText.verticalCenter
            visible: head.name === "Log" && !sidebar.expanded
            text: BosunLook.expand
            color: expandHover.hovered ? Theme.foregroundStrong : Theme.foregroundMuted
            font.pixelSize: 14

            HoverHandler {
                id: expandHover
            }

            TapHandler {
                onTapped: sidebar.logExpanded()
            }

            Tooltip {
                target: expandGlyph
                text: "The whole Log, expanded to the work area"
                hovered: expandHover.hovered
            }
        }
    }

    // What every row shares: the selected one's fill and edge, a hover, and
    // a click that selects it.
    component RowBase: Item {
        id: base

        required property string rowKey
        readonly property bool current: sidebar.selected === rowKey
        readonly property bool hovered: hover.hovered

        height: 36

        Rectangle {
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            radius: Theme.radius - 4
            color: base.current ? Theme.tint(0.07) : hover.hovered ? Theme.tint(0.04) : "transparent"

            Rectangle {
                width: 2
                height: parent.height
                visible: base.current
                color: sidebar.focused ? Theme.blue : Theme.foregroundFaint
            }

            Behavior on color {
                ColorAnimation {
                    duration: 150
                    easing.type: Easing.OutQuad
                }
            }
        }

        HoverHandler {
            id: hover
        }

        TapHandler {
            onTapped: sidebar.chosen(base.rowKey)
        }
    }

    // Its kind's glyph, the session, the tool or "asks", whether it is
    // reserved, or how it settled, its age, and under them the command, the
    // path or the question.
    component DecisionRow: RowBase {
        id: row

        required property string decisionId
        readonly property var live: Bosun.mine.find(d => d.id === decisionId) ?? null
        readonly property var decision: live ?? (sidebar.held?.id === decisionId ? sidebar.held : null)

        height: 57
        opacity: live ? 1 : 0.6

        BarText {
            id: kindGlyph

            x: 20
            y: 9
            text: row.decision ? BosunLook.decisionGlyph(row.decision) : ""
            color: Theme.foregroundMuted
            font.pixelSize: 14
        }

        BarText {
            id: nodeText

            anchors.left: kindGlyph.right
            anchors.leftMargin: 8
            anchors.baseline: kindGlyph.baseline
            text: row.decision?.node ?? ""
            font.pixelSize: 14
        }

        BarText {
            anchors.left: nodeText.right
            anchors.leftMargin: 8
            anchors.right: badge.visible ? badge.left : ageText.left
            anchors.rightMargin: badge.visible || ageText.text ? 8 : 0
            anchors.baseline: kindGlyph.baseline
            elide: Text.ElideRight
            text: {
                const d = row.decision;
                if (!d)
                    return "";
                const kind = Bosun.kindOf(d);
                return kind === "permission" ? d.tool : kind === "question" ? "asks" : "says";
            }
            color: Theme.foregroundMuted
            font.pixelSize: 13
        }

        Rectangle {
            id: badge

            readonly property bool reserved: (row.decision?.reserved ?? "") !== ""

            anchors.right: ageText.left
            anchors.rightMargin: ageText.text ? 8 : 0
            anchors.verticalCenter: kindGlyph.verticalCenter
            visible: reserved || !row.live
            width: badgeText.implicitWidth + 12
            height: 20
            radius: 4
            color: row.live ? Theme.alpha(Theme.yellow, 0.15) : Theme.tint(0.06)

            BarText {
                id: badgeText

                anchors.centerIn: parent
                text: {
                    if (row.live)
                        return `${BosunLook.reserved} reserved`;
                    if (Bosun.masters.some(d => d.id === row.decisionId))
                        return `${BosunLook.master} with the master`;
                    const entry = Bosun.settledEntry(row.decisionId);
                    const outcome = entry ? BosunLook.outcomeOf(entry) : "settled";
                    return outcome === "withdrawn" ? `${BosunLook.cancel} withdrawn` : outcome;
                }
                color: row.live ? Theme.yellow : Theme.foregroundMuted
                font.pixelSize: 12
            }
        }

        Caption {
            id: ageText

            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.baseline: kindGlyph.baseline
            text: BosunLook.age(Bosun.askedAt(row.decision ?? { id: row.decisionId }), sidebar.now)
        }

        // Time left before the session's own prompt takes over, at a fixed
        // width so the summary does not reflow as it ticks.
        Caption {
            id: leftText

            readonly property real remaining: row.live ? BosunLook.untilExpiry(row.decision, sidebar.now) : -1

            anchors.right: parent.right
            anchors.rightMargin: 20
            y: 33
            width: 64
            horizontalAlignment: Text.AlignRight
            visible: remaining >= 0
            text: `${BosunLook.clock} ${BosunLook.leftShort(remaining)}`
            color: remaining < 300000 ? Theme.red : remaining < 900000 ? Theme.yellow : Theme.foregroundMuted
        }

        BarText {
            x: nodeText.x
            y: 33
            width: parent.width - x - 20 - (leftText.visible ? leftText.width + 8 : 0)
            elide: Text.ElideRight
            text: row.decision ? Bosun.summaryOf(row.decision).split("\n")[0] : ""
            color: Theme.foregroundMuted
            font.family: row.decision && Bosun.kindOf(row.decision) === "permission" ? Theme.fontMono : Theme.fontUI
            font.pixelSize: 13
        }
    }

    // The front desk, a dot while it holds a reply the user has not seen,
    // its model, and under them what it does or last said. Without a desk,
    // the master, whom a tell then reaches.
    component DeskRow: RowBase {
        id: row

        readonly property var session: Bosun.desk ?? Bosun.master
        readonly property var activity: Bosun.desk?.activity ?? null
        readonly property string activityLine: activity ? BosunLook.activityText(activity) : ""
        readonly property color activityColor: Bosun.desk && BosunLook.stateOf(Bosun.desk) === "working" ? Theme.blue : Theme.foregroundMuted

        height: activityLine ? 52 : 36

        BarText {
            id: deskGlyph

            x: 20
            y: row.activityLine ? 8 : (row.height - height) / 2
            text: Bosun.desk ? BosunLook.desk : BosunLook.master
            color: Theme.foregroundMuted
            font.pixelSize: 14
        }

        BarText {
            id: deskName

            anchors.left: deskGlyph.right
            anchors.leftMargin: 8
            anchors.verticalCenter: deskGlyph.verticalCenter
            text: Bosun.desk ? "Front desk" : "Master"
            font.pixelSize: 14
        }

        Rectangle {
            anchors.left: deskName.right
            anchors.leftMargin: 8
            anchors.verticalCenter: deskGlyph.verticalCenter
            visible: BosunKept.deskUnread
            width: 6
            height: 6
            radius: 3
            color: Theme.blue
        }

        // How full its context window is, in the column at the right that
        // every row's bar shares, centred on the name line.
        BosunContextBar {
            id: deskBar

            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: deskGlyph.verticalCenter
            width: 32
            height: 3
            visible: row.session?.context !== undefined
            context: row.session?.context ?? null
        }

        // Ends 8 px left of the bar's column, with or without a bar.
        Caption {
            id: deskModel

            anchors.right: deskBar.left
            anchors.rightMargin: 8
            anchors.verticalCenter: deskGlyph.verticalCenter
            text: [row.session?.model, row.session?.effort].filter(part => part).join(" ")
        }

        Row {
            visible: row.activityLine !== ""
            x: deskName.x
            y: 30
            width: parent.width - x - 20
            spacing: 6

            BarText {
                id: deskActivityGlyph

                text: row.activity ? BosunLook.activityGlyph(row.activity) : ""
                color: row.activityColor
                font.pixelSize: 12
            }

            BarText {
                width: parent.width - deskActivityGlyph.width - parent.spacing
                elide: Text.ElideRight
                text: row.activityLine
                color: row.activityColor
                font.family: BosunLook.activityMono(row.activity) ? Theme.fontMono : Theme.fontUI
                font.pixelSize: 12
            }
        }
    }

    // A session, indented under its parent: its state's glyph, whose tooltip
    // gives the words, its name, and its model and effort.
    component SessionRow: RowBase {
        id: row

        required property string node
        readonly property var session: Bosun.sessions.find(s => s.node === node) ?? null
        readonly property string stateKey: session ? BosunLook.stateOf(session) : "stopped"
        readonly property bool resting: ["stopped", "killed"].includes(stateKey)

        readonly property var activity: session?.activity ?? null
        readonly property string activityLine: activity ? BosunLook.activityText(activity) : ""
        readonly property color activityColor: stateKey === "working" ? Theme.blue : Theme.foregroundMuted

        height: activityLine ? 52 : 32

        BarText {
            id: stateGlyph

            x: 20 + 16 * (row.session?.depth ?? 0)
            y: 8
            text: BosunLook.states[row.stateKey].glyph
            color: row.stateKey === "working" ? "transparent" : BosunLook.stateColor(row.stateKey)
            font.pixelSize: 14

            // The glyph's box holds the spinner's place, so the row keeps its
            // size. Not hidden by opacity, which the spinner would inherit.
            BosunSpinner {
                anchors.centerIn: parent
                visible: row.stateKey === "working"
                size: 12
            }

            HoverHandler {
                id: glyphHover
            }

            Tooltip {
                target: stateGlyph
                text: row.session ? BosunLook.stateWords(row.session) : ""
                hovered: glyphHover.hovered
            }
        }

        BarText {
            id: nameText

            anchors.left: stateGlyph.right
            anchors.leftMargin: 8
            anchors.right: modelText.left
            anchors.rightMargin: 8
            y: 8
            elide: Text.ElideRight
            text: row.node
            color: row.resting ? Theme.foregroundMuted : Theme.foregroundStrong
            font.pixelSize: 14
        }

        // How full its context window is, in the column at the right that
        // every row's bar shares whatever its indent, centred on the name line.
        BosunContextBar {
            id: contextBar

            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: stateGlyph.verticalCenter
            width: 32
            height: 3
            visible: row.session?.context !== undefined
            context: row.session?.context ?? null
        }

        // Ends 8 px left of the bar's column, with or without a bar.
        Caption {
            id: modelText

            anchors.right: contextBar.left
            anchors.rightMargin: 8
            anchors.verticalCenter: stateGlyph.verticalCenter
            text: [row.session?.model, row.session?.effort].filter(part => part).join(" ")
        }

        // What the session does, under its name: its tool's glyph and the call
        // in monospace, or the start of its last message. Blue in its turn.
        Row {
            visible: row.activityLine !== ""
            x: nameText.x
            y: 30
            width: parent.width - x - 20
            spacing: 6

            BarText {
                id: activityGlyph

                text: row.activity ? BosunLook.activityGlyph(row.activity) : ""
                color: row.activityColor
                font.pixelSize: 12
            }

            BarText {
                width: parent.width - activityGlyph.width - parent.spacing
                elide: Text.ElideRight
                text: row.activityLine
                color: row.activityColor
                font.family: BosunLook.activityMono(row.activity) ? Theme.fontMono : Theme.fontUI
                font.pixelSize: 12
            }
        }
    }

    // A Log entry on one line, and how long ago it came.
    component LogRow: RowBase {
        id: row

        required property var entry

        height: 28

        BarText {
            id: logGlyph

            x: 20
            anchors.verticalCenter: parent.verticalCenter
            text: BosunLook.logGlyph(row.entry)
            color: BosunLook.logColor(row.entry)
            font.pixelSize: 14
        }

        BarText {
            anchors.left: logGlyph.right
            anchors.leftMargin: 8
            anchors.right: timeText.left
            anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            text: BosunLook.logLine(row.entry)
            font.pixelSize: 13
        }

        Caption {
            id: timeText

            anchors.right: parent.right
            anchors.rightMargin: 20
            anchors.verticalCenter: parent.verticalCenter
            text: BosunLook.age(row.entry.at, sidebar.now)
        }
    }
}
