pragma ComponentBehavior: Bound

import QtQuick

// A Log entry whole: who acted and when, its text, and for a decision its
// call or question, the answer it was given and why it was withdrawn. An
// entry of a kind the panel does not know shows its kind and raw JSON.
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
            return "";
        case "settled":
            return entry.text ?? "";
        }
        return entry.text ?? "";
    }

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
            text: pane.entry?.at ? Qt.formatDateTime(new Date(pane.entry.at), "MMM d HH:mm") : ""
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
    Column {
        width: parent.width
        visible: pane.known && pane.entry.kind === "escalated" && (pane.entry.text ?? "") !== ""
        spacing: 4

        BosunFact {
            glyph: BosunLook.master
            text: "Why the master passed it to you"
        }

        BarText {
            width: parent.width
            wrapMode: Text.Wrap
            font.pixelSize: 14
            text: pane.entry?.text ?? ""
        }
    }

    BarText {
        width: parent.width
        visible: pane.known && pane.entry.kind === "settled" && pane.entry.withdrawn === true
        wrapMode: Text.Wrap
        color: Theme.foregroundMuted
        font.pixelSize: 14
        text: pane.entry?.cause ? `Withdrawn when ${pane.entry.cause}.` : "Withdrawn: nobody answered it."
    }

    BarText {
        width: parent.width
        visible: pane.said !== ""
        wrapMode: Text.Wrap
        font.pixelSize: 14
        text: pane.known && pane.entry.kind === "settled" && pane.entry.behavior === "deny" ? `Denied with: ${pane.said}` : pane.said
    }

    BarText {
        width: parent.width
        visible: (pane.entry?.words ?? "") !== ""
        wrapMode: Text.Wrap
        color: Theme.foregroundMuted
        font.pixelSize: 14
        text: `You said: “${pane.entry?.words ?? ""}”`
    }

    // The decision as it stood then.
    Column {
        width: parent.width
        visible: pane.decision !== null && pane.entry.kind === "settled"
        spacing: 4

        Caption {
            text: pane.decision?.kind === "permission" ? `${pane.decision.node} asked to use ${pane.decision.tool}` : `${pane.decision?.node ?? ""} asked`
        }

        BarText {
            width: parent.width
            visible: pane.decision?.kind !== "permission"
            wrapMode: Text.Wrap
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
                    keys: ["j", "k"],
                    text: "move"
                }
            ]
        }
    ]
}
