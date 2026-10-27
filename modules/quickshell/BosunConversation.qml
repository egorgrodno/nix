pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell

// A session's conversation, oldest at the top: its entries, then the turn in
// progress and the session's own prompt, if one waits. It keeps to the bottom
// as entries come until scrolled up, and fetches older entries at the top.
Item {
    id: conversation

    // The session's node.
    property string node
    // Its parent's node, whose prompts read as prompts rather than messages.
    property string parentNode
    // Off for a session gone from the fleet: what it showed stays, and
    // nothing new comes.
    property bool live: true
    readonly property alias feed: feed
    readonly property var progress: feed.progress
    // The session's status as `bosun watch` has it, "waiting" in a dialog of
    // its turn and "idle" once its turn ends.
    property string status: ""
    // Whether that has it in its turn, for when the daemon sends no progress.
    readonly property bool busy: ["busy", "waiting"].includes(status)
    // Claude Code's tempo reads "blocked" both on a dialog mid-turn and after
    // a turn that ends on a question, with the question in `needs` either
    // way. The daemon's status, which its Stop hook ends, tells them apart.
    readonly property bool inTurn: {
        const tempo = progress?.tempo ?? "";
        if (tempo === "")
            return busy;
        return tempo !== "idle" && (tempo !== "blocked" || busy);
    }
    // A message sent from the panel whose turn shows nothing yet: the id of
    // the feed's last entry when it went, its args as `Bosun.finished` gives
    // them, and whether the session has been in a turn since.
    property var sent: null
    // Shows the Working row: a message sent, or a turn with only its prompt.
    readonly property bool waiting: {
        if (sent !== null)
            return true;
        const last = feed.entries[feed.entries.length - 1];
        return inTurn && ["prompt", "queued", "task"].includes(last?.kind);
    }
    // The prompt the session shows: "approve Bash: …" or "answer: q (A · B)".
    // Claude Code leaves it set into the next turn, so it counts only while
    // the session is blocked.
    readonly property string needs: progress?.tempo === "blocked" ? progress.needs ?? "" : ""
    // The daemon's reading of `needs`, else the panel's own.
    readonly property var need: {
        if (needs === "")
            return null;
        if (progress.need)
            return progress.need;
        const permission = needs.match(/^approve ([^:]+): ([^]*)$/);
        if (permission)
            return {
                kind: "permission",
                tool: permission[1],
                detail: permission[2]
            };
        const question = needs.match(/^answer: ([^]*?)(?: \((.*)\))?$/);
        if (question)
            return {
                kind: "question",
                question: question[1],
                options: question[2]?.split(" · ")
            };
        return {
            kind: "other",
            text: needs
        };
    }
    // The decision that holds the session's permission, which approve and
    // deny answer.
    readonly property var needsDecision: need?.kind === "permission" ? Bosun.decisions.find(d => d.node === node && Bosun.kindOf(d) === "permission") ?? null : null
    property real now: Date.now()
    // Each id whose open state differs from its kind's default.
    property var flipped: ({})
    // Whether the view keeps to the newest entry.
    property bool following: true
    // What BosunKept keeps the view's place under, or "" to keep none.
    property string scrollKey: ""
    // While the view moves on its own, which neither keeps its place nor
    // stops it following.
    property bool restoring: false
    // Whether the view has taken the place kept for it. The list lays out
    // and follows its end before the feed's first page comes, and a place
    // stored then would replace the one kept.
    property bool placed: false

    // Turns the feed's entries into those shown, as BosunDesk.shape does for
    // the desk; null shows them as they come.
    property var shape: null
    // The rows `steady` handed out last, by id, the ids of those that arrived
    // since and wait for their rows to animate in, and whether the view
    // glides to its end for them; set without a change signal, as the binding
    // that reads it writes it.
    readonly property var shownBefore: ({
            rows: {},
            arriving: {},
            glide: false
        })

    // A decision's row is selected, as the sidebar does.
    signal decisionOpened(string id)
    // A row the conversation names is selected, as `BosunLook.logLink` gives
    // it.
    signal opened(string key, var item)

    // Leaves thinking out but for one row while the session thinks: in its
    // turn, with thinking its latest entry before any prompt queued for the
    // turn. The progress line's state and detail never say thinking. One id
    // for every such row lets `steady` keep it through a run of thinking.
    // While `waiting`, a Working row ends them, unless a row or the progress
    // line already shows the turn running.
    function fold(entries) {
        let latest = null;
        for (const e of entries)
            if (!["queued", "desk-pending"].includes(e.kind))
                latest = e;
        const thinks = inTurn && latest?.kind === "thinking";
        const runs = inTurn && (thinks || latest?.kind === "tool" && !latest.result || (progress?.detail ?? "") !== "");
        const out = [];
        for (const e of entries)
            if (e.kind !== "thinking")
                out.push(e);
            else if (thinks && e === latest)
                out.push({
                    id: "thinking-now",
                    kind: "thinking"
                });
        if (waiting && !runs)
            out.push({
                id: "working-now",
                kind: "working",
                started: sent === null || sent.started
            });
        return out;
    }

    // Ends `sent` once an entry of the session's own lands after it.
    function settle() {
        if (sent === null)
            return;
        const at = feed.places[sent.last];
        if (sent.last !== "" && at === undefined)
            return;
        if (feed.entries.slice(sent.last === "" ? 0 : at + 1).some(e => !["prompt", "queued", "task", "meta", "cleared"].includes(e.kind)))
            sent = null;
    }

    // Hands back the row shown before for each entry whose fields are all the
    // same, since fold and shape build theirs anew on every update and the
    // model refreshes a delegate whose row is not the same object. A row new
    // to the view arrives, animating in, but for those a reset's page, an
    // older page or `bosun watch` coming back brings.
    function steady(entries) {
        const before = shownBefore.rows;
        const arrives = !feed.quiet && feed.session !== "" && Bosun.connected;
        const rows = {};
        const out = entries.map(e => {
            const was = before[e.id];
            const keys = Object.keys(e);
            const row = was && Object.keys(was).length === keys.length && keys.every(k => was[k] === e[k]) ? was : e;
            rows[e.id] = row;
            if (!was && arrives) {
                shownBefore.arriving[e.id] = true;
                shownBefore.glide = following;
            }
            return row;
        });
        if (!arrives)
            shownBefore.glide = false;
        for (const id in shownBefore.arriving)
            if (!rows[id])
                delete shownBefore.arriving[id];
        shownBefore.rows = rows;
        return out;
    }

    // Whether the row for `id` animates in, once: only its first delegate
    // does.
    function arrives(id) {
        const was = shownBefore.arriving[id] === true;
        delete shownBefore.arriving[id];
        return was;
    }

    function isOpen(id, byDefault) {
        return flipped[id] === true ? !byDefault : byDefault;
    }

    function toggle(id) {
        const next = Object.assign({}, flipped);
        if (next[id])
            delete next[id];
        else
            next[id] = true;
        flipped = next;
    }

    // Where the view is, for `restore`: following the newest, or an entry and
    // how far past its top.
    function position() {
        if (following)
            return {
                follow: true
            };
        // Past the header, which a scroll to the top shows, and the spacing
        // between rows, neither of which holds an entry.
        const y = Math.max(list.contentY, list.originY + (list.headerItem?.height ?? 0)) + 1;
        const index = [y, y + list.spacing].map(at => list.indexAt(10, at)).find(i => i >= 0) ?? -1;
        const item = list.itemAtIndex(index);
        if (!item || index < 0)
            return {
                follow: true
            };
        return {
            id: shown.values[index].id,
            offset: list.contentY - item.y
        };
    }

    // Once the view has laid out what changed.
    function restore(at) {
        glide.stop();
        restoring = true;
        restorer.at = at;
        restorer.restart();
    }

    // A hidden pane empties its list, which keeps nothing.
    function keeps() {
        return scrollKey !== "" && placed && visible && !feed.opening;
    }

    function keep() {
        if (keeps() && !restoring)
            BosunKept.keepScroll(scrollKey, position());
    }

    // Stores the pinned state, which `keep` skips while the view glides to the
    // end on its own.
    function pin() {
        if (keeps())
            BosunKept.keepScroll(scrollKey, {
                follow: true
            });
    }

    onNodeChanged: {
        flipped = {};
        placed = false;
        revealer.stop();
        fadeIn.stop();
        list.opacity = 0;
        following = true;
        sent = null;
    }
    // A turn that ends before any entry of its own lands, as one that fails
    // at once does.
    onInTurnChanged: {
        if (sent === null)
            return;
        if (inTurn)
            sent = Object.assign({}, sent, {
                started: true
            });
        else if (sent.started)
            sent = null;
    }
    onBusyChanged: if (busy && sent !== null && !sent.started)
        sent = Object.assign({}, sent, {
            started: true
        })

    Connections {
        target: Bosun

        function onSending(node, args) {
            if (node !== conversation.node || !conversation.live)
                return;
            conversation.sent = {
                last: feed.entries[feed.entries.length - 1]?.id ?? "",
                args: JSON.stringify(args),
                started: conversation.inTurn
            };
        }

        // `Bosun.error` shows why.
        function onFinished(args, ok) {
            if (!ok && JSON.stringify(args) === conversation.sent?.args)
                conversation.sent = null;
        }
    }

    // A send the session never starts a turn for, as on a daemon that lost
    // it.
    Timer {
        running: conversation.sent !== null && !conversation.sent.started
        interval: 30000
        onTriggered: conversation.sent = null
    }

    BosunFeed {
        id: feed

        property var kept: null

        node: conversation.node
        live: conversation.live
        onPrepending: kept = conversation.position()
        onPrepended: conversation.restore(kept)
        onOpened: conversation.restore(conversation.scrollKey !== "" ? BosunKept.scroll(conversation.scrollKey) : null)
        onEntriesChanged: conversation.settle()
    }

    // Timers rather than Qt.callLater, which can outlive a pane destroyed in
    // between.
    Timer {
        id: restorer

        property var at: null

        interval: 0
        onTriggered: {
            const index = at && !at.follow ? shown.values.findIndex(e => e.id === at.id) : -1;
            conversation.following = index < 0;
            if (index < 0)
                list.positionViewAtEnd();
            else {
                list.positionViewAtIndex(index, ListView.Beginning);
                list.contentY += at.offset ?? 0;
            }
            conversation.restoring = false;
            conversation.placed = true;
            if (list.opacity === 0)
                revealer.restart();
        }
    }

    Timer {
        id: toEnd

        interval: 0
        onTriggered: {
            // A scroll up lays out the entries it reaches, which restarts
            // this before the view stops following.
            if (!conversation.following)
                return;
            conversation.restoring = true;
            const from = list.contentY;
            list.positionViewAtEnd();
            const to = list.contentY;
            // A row that arrives glides in from below, as does any growth
            // while the glide runs.
            if ((conversation.shownBefore.glide || glide.running) && to > from) {
                list.contentY = from;
                glide.from = from;
                glide.to = to;
                glide.restart();
                conversation.restoring = true;
            } else {
                glide.stop();
                conversation.restoring = false;
                conversation.pin();
            }
            conversation.shownBefore.glide = false;
        }
    }

    // Keeps `restoring` while it runs, so the view still follows.
    NumberAnimation {
        id: glide

        target: list
        property: "contentY"
        duration: 200
        easing.type: Easing.OutCubic
        onRunningChanged: if (!running) {
            conversation.restoring = false;
            if (conversation.following)
                conversation.pin();
        }
    }

    // Shows the list once it is placed and its rows have stopped growing,
    // so a conversation opens where it will stay rather than at its top.
    Timer {
        id: revealer

        interval: 50
        onTriggered: fadeIn.start()
    }

    NumberAnimation {
        id: fadeIn

        target: list
        property: "opacity"
        to: 1
        duration: 150
        easing.type: Easing.OutCubic
    }

    // Ticks the times, each second in a turn, as a running call counts them.
    Timer {
        running: conversation.visible
        interval: conversation.inTurn ? 1000 : 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: conversation.now = Date.now()
    }

    ListView {
        id: list

        anchors.fill: parent
        opacity: 0
        clip: true
        spacing: 12
        boundsBehavior: Flickable.StopAtBounds
        // Builds every loaded row, as the feed holds a few pages at most:
        // a ListView guesses the height of the rows it has not built from
        // those it has, and rows differ so much that the guess, and with it
        // the scroll bar, swings as the view moves.
        cacheBuffer: 1000000
        model: ScriptModel {
            id: shown

            objectProp: "id"
            values: conversation.steady(conversation.fold((conversation.shape ? conversation.shape(feed.entries) : feed.entries).filter(e => e.kind !== "meta" && !(e.kind === "queued" && e.taken))))
        }

        delegate: BosunEntry {
            conversation: conversation
        }

        header: Item {
            width: ListView.view.width
            height: feed.more || feed.loadingOlder ? 32 : 0

            Caption {
                anchors.centerIn: parent
                visible: parent.height > 0
                text: feed.loadingOlder ? "Loading earlier entries…" : "Scroll up for earlier entries"
            }
        }

        footer: Column {
            width: ListView.view.width
            topPadding: 12

            // What the turn does, as Claude Code's status line says.
            Reveal {
                id: status

                readonly property string detail: conversation.inTurn ? conversation.progress?.detail ?? "" : ""
                // What it showed last, which stays while it closes.
                property string last: ""

                open: detail !== ""
                onDetailChanged: if (detail !== "")
                    last = detail

                Row {
                    width: parent.width
                    // The 12 between it and the card below.
                    bottomPadding: 12
                    spacing: 8

                    // On the text, as the row's centre takes in its padding.
                    BosunSpinner {
                        anchors.verticalCenter: label.verticalCenter
                        size: 12
                    }

                    BarText {
                        id: label

                        width: parent.width - 20
                        elide: Text.ElideRight
                        text: status.last
                        color: Theme.blue
                        font.pixelSize: 13
                    }
                }
            }

            Reveal {
                open: conversation.needs !== ""

                NeedsCard {}
            }
        }

        onContentHeightChanged: {
            if (conversation.following)
                toEnd.restart();
            if (revealer.running)
                revealer.restart();
        }
        // Only the user's scroll lets go of the end or takes the view back
        // to it: the list moves the view itself as rows and the footer grow,
        // short of the end until `toEnd` runs. The scroll bar moves it
        // without a movement.
        onContentYChanged: {
            if (conversation.restoring || feed.opening)
                return;
            if (moving || scrollBar.pressed)
                conversation.following = atYEnd;
            conversation.keep();
        }
        // A scroll takes the view from the glide.
        onMovementStarted: glide.stop()
        onAtYBeginningChanged: if (atYBeginning && !conversation.following)
            feed.loadOlder()

        ScrollBar.vertical: BosunScrollBar {
            id: scrollBar
        }
    }

    // Takes the view back to the newest entry and pins it there, as an entry
    // arriving does. It rides above the footer's status row and prompt card
    // while they are in view, and stays clear of the scroll bar.
    BosunJumpButton {
        id: jump

        readonly property real footerShown: Math.max(0, list.contentY + list.height - (list.originY + list.contentHeight - (list.footerItem?.height ?? 0)))

        anchors.right: parent.right
        anchors.rightMargin: 20
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12 + footerShown
        shown: !conversation.following && list.contentHeight > list.height && !list.atYEnd
        onClicked: {
            conversation.shownBefore.glide = true;
            conversation.following = true;
            conversation.pin();
            toEnd.restart();
        }
    }

    // Opens to its content's height with a fade, and closes the same way, so
    // the list's footer grows and shrinks rather than snapping. The list
    // follows the newest entry through it as through any growth.
    component Reveal: Item {
        id: reveal

        property bool open: false
        default property alias content: body.data

        width: parent?.width ?? 0
        height: open ? body.height : 0
        visible: height > 0
        opacity: open ? 1 : 0
        clip: true

        Behavior on height {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutCubic
            }
        }

        Item {
            id: body

            width: parent.width
            height: childrenRect.height
        }
    }

    // The session's own prompt: a question's options, which answer it as the
    // user, or the permission's decision with Deny and Approve.
    component NeedsCard: Rectangle {
        id: card

        // What it showed last, which stays while its Reveal closes.
        property var need: null
        property var decision: null
        readonly property var liveNeed: conversation.need
        readonly property var liveDecision: conversation.needsDecision
        readonly property bool mine: decision?.holder === "user"

        // The decision follows the need, and ends before it, so it keeps the
        // last one the need had.
        onLiveNeedChanged: if (liveNeed) {
            need = liveNeed;
            decision = liveDecision;
        }
        onLiveDecisionChanged: if (liveNeed)
            decision = liveDecision
        Component.onCompleted: {
            need = liveNeed;
            decision = liveDecision;
        }

        width: parent?.width ?? 0
        height: cardBody.implicitHeight + 24
        radius: Theme.radius - 4
        color: Theme.alpha(Theme.yellow, 0.08)
        border.width: 1
        border.color: Theme.alpha(Theme.yellow, 0.4)

        Column {
            id: cardBody

            x: 12
            y: 12
            width: parent.width - 24
            spacing: 10

            BosunFact {
                glyph: BosunLook.states.blocked.glyph
                glyphColor: Theme.yellow
                text: {
                    switch (card.need?.kind) {
                    case "question":
                        return `${conversation.node} asks`;
                    case "permission":
                        return `${conversation.node} asks to use ${card.need.tool} in its own prompt`;
                    }
                    return `${conversation.node} waits on its own prompt`;
                }
            }

            BarText {
                width: parent.width
                wrapMode: Text.Wrap
                text: {
                    const need = card.need;
                    return need?.kind === "question" ? need.question : need?.kind === "permission" ? need.detail : need?.text ?? "";
                }
                font.family: card.need?.kind === "permission" ? Theme.fontMono : Theme.fontUI
                font.pixelSize: card.need?.kind === "permission" ? 13 : 14
            }

            Flow {
                width: parent.width
                visible: (card.need?.options ?? []).length > 0
                spacing: 6

                Repeater {
                    model: card.need?.options ?? []

                    TextButton {
                        required property string modelData

                        text: modelData
                        onClicked: Bosun.say(conversation.node, modelData)
                    }
                }
            }

            Row {
                visible: card.decision !== null
                spacing: 8

                TextButton {
                    visible: card.mine
                    text: `${BosunLook.close}  Deny`
                    hoverFill: Theme.red
                    litTextColor: Theme.backgroundMain
                    onClicked: Bosun.deny(card.decision.id, "")
                }

                TextButton {
                    visible: card.mine
                    text: `${BosunLook.check}  Approve`
                    hoverFill: Theme.green
                    litTextColor: Theme.backgroundMain
                    onClicked: Bosun.approve(card.decision.id)
                }

                TextButton {
                    visible: card.mine
                    text: "Open the decision"
                    onClicked: conversation.decisionOpened(card.decision.id)
                }

                Caption {
                    visible: !card.mine
                    height: 28
                    verticalAlignment: Text.AlignVCenter
                    text: `${BosunLook.master}  The master holds this decision`
                }
            }
        }
    }
}
