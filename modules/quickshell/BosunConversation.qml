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
    // The decision that holds the session's permission, which approve and
    // deny answer.
    readonly property var needsDecision: needs.startsWith("approve ") ? Bosun.decisions.find(d => d.node === node && (d.kind === "permission" || d.prompt === true)) ?? null : null
    readonly property var question: {
        const match = needs.match(/^answer: (.*) \((.*)\)$/);
        return match ? {
            text: match[1],
            options: match[2].split(" · ")
        } : null;
    }
    property real now: Date.now()
    // Each id whose open state differs from its kind's default.
    property var flipped: ({})
    // Whether the view keeps to the newest entry.
    property bool following: true

    // A decision's row is selected, as the sidebar does.
    signal decisionOpened(string id)

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
        const item = list.itemAt(10, list.contentY + 1);
        const index = list.indexAt(10, list.contentY + 1);
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
        restorer.at = at;
        restorer.restart();
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
    }

    // Timers rather than Qt.callLater, which can outlive a pane destroyed in
    // between.
    Timer {
        id: restorer

        property var at: null

        interval: 0
        onTriggered: {
            const index = at && !at.follow ? shown.values.findIndex(e => e.id === at.id) : -1;
            if (index < 0) {
                conversation.following = true;
                list.positionViewAtEnd();
                return;
            }
            conversation.following = false;
            list.positionViewAtIndex(index, ListView.Beginning);
            list.contentY += at.offset ?? 0;
        }
    }

    Timer {
        id: toEnd

        interval: 0
        onTriggered: list.positionViewAtEnd()
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
            values: feed.entries.filter(e => e.kind !== "meta" && !(e.kind === "queued" && e.taken))
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
        onMovementEnded: conversation.following = atYEnd
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
                text: conversation.question ? `${conversation.node} asks` : conversation.needs.startsWith("approve ") ? `${conversation.node} waits on its own permission prompt` : `${conversation.node} waits on its own prompt`
            }

            BarText {
                width: parent.width
                wrapMode: Text.Wrap
                text: conversation.question?.text ?? conversation.needs.replace(/^approve /, "")
                font.family: conversation.question ? Theme.fontUI : Theme.fontMono
                font.pixelSize: conversation.question ? 14 : 13
            }

            Flow {
                width: parent.width
                visible: conversation.question !== null
                spacing: 6

                Repeater {
                    model: conversation.question?.options ?? []

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
