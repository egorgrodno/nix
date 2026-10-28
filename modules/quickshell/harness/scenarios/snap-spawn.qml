import QtQuick

// A PNG of the New worker form on a long draft, and the height each of its
// text fields reached. Runs on the `spawn` pane only (`run.sh -p spawn`).
QtObject {
    property int frames: 4

    function step(h, f) {
        if (h.pane !== "spawn")
            return false;
        if (f === 0) {
            h.walk(h.conv, it => {
                if (it.maxLines !== undefined)
                    h.note(`field ${Math.round(it.width)}x${Math.round(it.height)} maxLines=${it.maxLines}`);
            });
            h.snap("form");
        }
    }
}
