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
    // Whether the session is in its turn as `bosun watch` has it, for when
    // the daemon sends no progress.
    property bool busy: false
    readonly property bool inTurn: (progress?.tempo ?? "") !== "" ? progress.tempo !== "idle" : busy
    // The prompt the session shows: "approve Bash: …" or "answer: q (A · B)".
    readonly property string needs: progress?.needs ?? ""
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

    // Turns the feed's entries into those shown, as BosunDesk.shape does for
    // the desk; null shows them as they come.
    property var shape: null
    // The rows `steady` handed out last, by id; set without a change signal,
    // as the binding that reads it writes it.
    readonly property var shownBefore: ({
            rows: {}
        })

    // A decision's row is selected, as the sidebar does.
    signal decisionOpened(string id)
    // A row the conversation names is selected, as `BosunLook.logLink` gives
    // it.
    signal opened(string key, var item)

    // Folds each run of thinking into the text or tool call after it, as
    // `thinking`. A run before anything else keeps its rows, as at the end
    // of a turn in progress.
    function fold(entries) {
        const out = [];
        let run = [];
        for (const e of entries) {
            if (e.kind === "thinking") {
                run.push(e);
                continue;
            }
            if (run.length > 0 && ["text", "tool", "desk-text"].includes(e.kind))
                out.push(Object.assign({}, e, {
                    thinking: run.map(t => (t.text ?? "").trim()).filter(t => t !== "").join("\n\n")
                }));
            else
                out.push(...run, e);
            run = [];
        }
        return out.concat(run);
    }

    // Hands back the row shown before for each entry whose fields are all the
    // same, since fold and shape build theirs anew on every update and the
    // model refreshes a delegate whose row is not the same object.
    function steady(entries) {
        const before = shownBefore.rows;
        const rows = {};
        const out = entries.map(e => {
            const was = before[e.id];
            const keys = Object.keys(e);
            const row = was && Object.keys(was).length === keys.length && keys.every(k => was[k] === e[k]) ? was : e;
            rows[e.id] = row;
            return row;
        });
        shownBefore.rows = rows;
        return out;
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
        restoring = true;
        restorer.at = at;
        restorer.restart();
    }

    function keep() {
        if (scrollKey !== "" && !restoring && !feed.opening)
            BosunKept.keepScroll(scrollKey, position());
    }

    onNodeChanged: {
        flipped = {};
        following = true;
    }

    BosunFeed {
        id: feed

        property var kept: null

        node: conversation.node
        live: conversation.live
        onPrepending: kept = conversation.position()
        onPrepended: conversation.restore(kept)
        onOpened: conversation.restore(conversation.scrollKey !== "" ? BosunKept.scroll(conversation.scrollKey) : null)
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
            list.positionViewAtEnd();
            conversation.restoring = false;
        }
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
        clip: true
        spacing: 12
        boundsBehavior: Flickable.StopAtBounds
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
            spacing: 12

            // What the turn does, as Claude Code's status line says.
            BarText {
                width: parent.width
                visible: conversation.inTurn && (conversation.progress?.detail ?? "") !== ""
                elide: Text.ElideRight
                text: `${BosunLook.running}  ${conversation.progress?.detail ?? ""}`
                color: Theme.blue
                font.pixelSize: 13
            }

            NeedsCard {
                visible: conversation.needs !== ""
            }
        }

        onContentHeightChanged: if (conversation.following)
            toEnd.restart()
        // The scroll bar moves the view without a movement.
        onContentYChanged: {
            if (conversation.restoring || feed.opening)
                return;
            conversation.following = atYEnd;
            conversation.keep();
        }
        onAtYBeginningChanged: if (atYBeginning && !conversation.following)
            feed.loadOlder()

        ScrollBar.vertical: ScrollBar {
            policy: list.contentHeight > list.height ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff

            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: Theme.tint(0.25)
            }
        }
    }

    // The session's own prompt: a question's options, which answer it as the
    // user, or the permission's decision with Deny and Approve.
    component NeedsCard: Rectangle {
        id: card

        readonly property var decision: conversation.needsDecision
        readonly property bool mine: decision?.holder === "user"

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
                    switch (conversation.need?.kind) {
                    case "question":
                        return `${conversation.node} asks`;
                    case "permission":
                        return `${conversation.node} asks to use ${conversation.need.tool} in its own prompt`;
                    }
                    return `${conversation.node} waits on its own prompt`;
                }
            }

            BarText {
                width: parent.width
                wrapMode: Text.Wrap
                text: {
                    const need = conversation.need;
                    return need?.kind === "question" ? need.question : need?.kind === "permission" ? need.detail : need?.text ?? "";
                }
                font.family: conversation.need?.kind === "permission" ? Theme.fontMono : Theme.fontUI
                font.pixelSize: conversation.need?.kind === "permission" ? 13 : 14
            }

            Flow {
                width: parent.width
                visible: (conversation.need?.options ?? []).length > 0
                spacing: 6

                Repeater {
                    model: conversation.need?.options ?? []

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
                    hoverFill: Theme.alpha(Theme.red, 0.5)
                    onClicked: Bosun.deny(card.decision.id, "")
                }

                TextButton {
                    visible: card.mine
                    text: `${BosunLook.check}  Approve`
                    hoverFill: Theme.alpha(Theme.green, 0.5)
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
