pragma ComponentBehavior: Bound

import QtQuick

// A Log entry whole: who acted and when, its text, and for a decision its
// call or question, the answer it was given and why it was withdrawn, then a
// button for each thing it names. An entry of a kind the panel does not know
// shows its kind and raw JSON.
BosunPane {
    id: pane

    property var entry: null
    readonly property bool known: entry !== null && BosunLook.knows(entry)
    readonly property var decision: known ? entry.decision ?? null : null
    // The entry's text, unless it repeats what the title or the call show.
    readonly property string said: {
        if (!known)
            return "";
        switch (entry.kind) {
        case "decision":
            return decision.kind === "permission" ? "" : Bosun.summaryOf(decision);
        case "escalated":
        case "allowed":
        case "sleeplock":
            return "";
        case "settled":
            return entry.text ?? "";
        }
        return entry.text ?? "";
    }
    // How a decision reached the user, as the daemon logs it: the route, the
    // reserved rule that caught it and what it matched, and how long it
    // waited; and the grant an entry is about.
    readonly property var details: {
        if (!known)
            return [];
        const waited = entry.waited ?? 0;
        const grant = entry.grant;
        return [
            entry.route ? {
                label: "Route",
                value: `${entry.route}: ${BosunLook.routeWords(entry.route)}`
            } : null,
            entry.rule ? {
                label: "Rule",
                value: entry.rule,
                mono: true
            } : null,
            entry.match ? {
                label: "Match",
                value: entry.match,
                mono: true
            } : null,
            waited > 0 ? {
                label: "Waited",
                value: BosunLook.span(waited * 1000)
            } : null,
            grant ? {
                label: "Grant",
                value: `${grant.id}: ${grant.class}`
            } : null,
            grant?.until ? {
                label: "Until",
                value: BosunLook.grantUntil(grant)
            } : null
        ].filter(row => row);
    }
    // What it names, as the expanded Log links it, and a message's sender.
    readonly property var links: {
        if (!entry)
            return [];
        const links = [BosunLook.logLink(entry), entry.kind === "message" ? BosunLook.sessionLink(entry.from) : null];
        return links.filter((link, i) => link && links.findIndex(l => l?.key === link.key) === i);
    }

    // A button followed: the key to select and what to hold for it.
    signal opened(string key, var item)

    title: entry ? BosunLook.logTitle(entry) : ""
    aside: decision ? `#${decision.id}` : ""
    facts: [
        BosunFact {
            glyph: pane.entry ? BosunLook.logGlyph(pane.entry) : ""
            glyphColor: pane.entry ? BosunLook.logColor(pane.entry) : Theme.foregroundMuted
            text: pane.entry ? pane.entry.kind.replace("_", " ") : ""
        },
        BosunFact {
            glyph: BosunLook.clock
            text: {
                if (!pane.entry?.at)
                    return "";
                const at = new Date(pane.entry.at);
                return at.toDateString() === new Date().toDateString() ? `Today at ${Qt.formatTime(at, "HH:mm")}` : Qt.formatDateTime(at, "MMM d HH:mm");
            }
        },
        BosunFact {
            glyph: BosunLook.folder
            text: BosunLook.tilde(pane.entry?.repo)
        },
        BosunFact {
            glyph: BosunLook.chip
            text: [pane.entry?.model, pane.entry?.effort].filter(part => part).join(" ")
        }
    ]

    // What the master passed on with an escalated decision.
    BosunWhyNote {
        visible: pane.known && pane.entry.kind === "escalated" && text !== ""
        text: pane.entry?.text ?? ""
    }

    SelectableText {
        width: parent.width
        visible: pane.known && pane.entry.kind === "settled" && pane.entry.withdrawn === true
        wrapMode: TextEdit.Wrap
        color: Theme.foregroundMuted
        font.pixelSize: 14
        text: pane.entry?.cause ? `Withdrawn when ${pane.entry.cause}.` : "Withdrawn: nobody answered it."
    }

    SelectableText {
        width: parent.width
        visible: pane.said !== ""
        wrapMode: TextEdit.Wrap
        font.pixelSize: 14
        text: pane.known && ["settled", "prompt"].includes(pane.entry.kind) && pane.entry.behavior === "deny" ? `Denied with: ${pane.said}` : pane.said
    }

    SelectableText {
        width: parent.width
        visible: (pane.entry?.error ?? "") !== ""
        wrapMode: TextEdit.Wrap
        color: Theme.red
        font.pixelSize: 14
        text: `Failed: ${pane.entry?.error ?? ""}`
    }

    BosunYouSaid {
        width: parent.width
        visible: words !== ""
        words: pane.entry?.words ?? ""
    }

    // The decision as it stood then.
    Column {
        width: parent.width
        visible: pane.decision !== null && ["settled", "parked"].includes(pane.entry.kind)
        spacing: 4

        Caption {
            text: pane.decision?.kind === "permission" ? `${pane.decision.node} asked to use ${pane.decision.tool}` : `${pane.decision?.node ?? ""} asked`
        }

        SelectableText {
            width: parent.width
            visible: pane.decision?.kind !== "permission"
            wrapMode: TextEdit.Wrap
            font.pixelSize: 14
            text: pane.decision ? Bosun.summaryOf(pane.decision) : ""
        }
    }

    Repeater {
        model: pane.decision?.kind === "permission" ? Bosun.callOf(pane.decision) : []

        delegate: BosunCallBlock {}
    }

    Column {
        width: parent.width
        visible: pane.details.length > 0
        spacing: 4

        Repeater {
            model: pane.details

            Row {
                id: fact

                required property var modelData

                spacing: 12

                Caption {
                    width: 56
                    text: fact.modelData.label
                }

                BarText {
                    width: pane.bodyWidth - 68
                    wrapMode: Text.Wrap
                    text: fact.modelData.value
                    font.family: fact.modelData.mono ? Theme.fontMono : Theme.fontUI
                    font.pixelSize: 13
                }
            }
        }
    }

    Row {
        visible: pane.links.length > 0
        spacing: 8

        Repeater {
            model: pane.links

            TextButton {
                required property var modelData

                text: modelData.text
                onClicked: pane.opened(modelData.key, modelData.item)
            }
        }
    }

    Column {
        width: parent.width
        visible: pane.entry !== null && !pane.known
        spacing: 8

        BosunFact {
            glyph: BosunLook.alert
            glyphColor: Theme.yellow
            text: `bosun can't show this entry yet: ${pane.entry?.kind ?? ""}`
        }

        BosunCallBlock {
            modelData: ({
                    kind: "code",
                    label: "",
                    text: pane.entry ? JSON.stringify(pane.entry, null, 2) : ""
                })
        }
    }

    foot: [
        BosunHints {
            model: [
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
    ]
}
