import QtQuick

// A PNG of the conversation at its newest entry and at its oldest, in
// `SNAPS` (run's `--snaps`). A snapshot renders on the frame after the one
// that asks, so the view moves two frames later.
QtObject {
    property int frames: 6

    function setup(h) {
        h.list.positionViewAtEnd();
    }

    function step(h, f) {
        if (f === 0)
            h.snap("end");
        if (f === 2)
            h.list.positionViewAtBeginning();
        if (f === 4)
            h.snap("start");
    }
}
