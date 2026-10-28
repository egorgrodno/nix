import QtQuick

// A list's delegate around a row that arrives and leaves: inserted into the
// model, it opens from nothing to `full` as it fades in, and removed, it
// closes as it fades out, the list keeping it until it has. A row the list
// builds as it scrolls, or on its first fill, shows at once. Its height
// follows the animation alone, never the layout around it.
Item {
    id: reveal

    // Whether arriving and leaving animate, rather than happen at once.
    property bool animates: true
    // The height it opens to: its row's.
    property real full
    // From 0, gone, to 1, whole.
    property real shown: 1

    height: full * shown
    opacity: shown
    clip: shown < 1

    ListView.onAdd: if (animates)
        arriving.start()
    ListView.onRemove: if (animates)
        leaving.start()

    // As long as a panel takes to open.
    NumberAnimation {
        id: arriving

        target: reveal
        property: "shown"
        from: 0
        to: 1
        duration: 200
        easing.type: Easing.OutCubic
    }

    SequentialAnimation {
        id: leaving

        ScriptAction {
            script: arriving.stop()
        }

        PropertyAction {
            target: reveal
            property: "ListView.delayRemove"
            value: true
        }

        NumberAnimation {
            target: reveal
            property: "shown"
            to: 0
            duration: 200
            easing.type: Easing.OutCubic
        }

        PropertyAction {
            target: reveal
            property: "ListView.delayRemove"
            value: false
        }
    }
}
