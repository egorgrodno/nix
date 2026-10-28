import QtQuick

// From the newest entry up through the whole conversation, 25 px a frame.
QtObject {
    property int frames: 150

    function setup(h) {
        h.list.positionViewAtEnd();
    }

    function step(h, f) {
        h.list.contentY = Math.max(h.list.originY, h.list.contentY - 25);
    }
}
