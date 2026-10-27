import QtQuick

// Compact and Clear beside a session's context bar. Clear takes a second
// press, and a master with workers cannot clear: the daemon refuses it.
Row {
    id: actions

    // The master or the desk.
    required property string node
    // While a first press or click has armed Clear.
    property bool clearArmed: false
    // Which of the two armed it, for the wording.
    property bool clearByKey: false

    readonly property bool clearBlocked: node === "master" && Bosun.hasWorkers

    signal compactClicked
    signal clearClicked

    visible: Bosun.connected
    spacing: 8

    TextButton {
        anchors.verticalCenter: parent.verticalCenter
        height: 22
        enabled: Bosun.contextOp === ""
        text: Bosun.contextOp === `compact ${actions.node}` ? `${BosunLook.compacted}  Compacting…` : `${BosunLook.compacted}  Compact`
        onClicked: actions.compactClicked()
    }

    Item {
        width: clearButton.width
        height: 22
        anchors.verticalCenter: parent.verticalCenter

        TextButton {
            id: clearButton

            height: parent.height
            enabled: !actions.clearBlocked && Bosun.contextOp === ""
            text: {
                if (Bosun.contextOp === `clear ${actions.node}`)
                    return `${BosunLook.cleared}  Clearing…`;
                if (actions.clearArmed)
                    return actions.clearByKey ? "Press C again to clear" : "Click again to clear";
                return `${BosunLook.cleared}  Clear`;
            }
            hoverFill: Theme.alpha(Theme.red, 0.5)
            lit: actions.clearArmed
            onClicked: actions.clearClicked()
        }

        HoverHandler {
            id: clearHover
        }

        Tooltip {
            target: clearButton
            text: "The master remembers its workers, so it clears only once none is left"
            hovered: actions.clearBlocked && clearHover.hovered
        }
    }
}
