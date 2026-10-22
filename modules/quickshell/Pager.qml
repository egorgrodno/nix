import QtQuick

// A page, and where the view stands as it slides there, fractional while two
// pages show: page i sits i - position strides across. A move of more than two
// pages cuts to the page beside the new one and slides the last step.
QtObject {
    id: pager

    property int page
    property real position
    property bool cut: false

    // Without `slide`, cuts straight to it.
    function go(to, slide = true) {
        if (!slide || Math.abs(to - position) > 2) {
            cut = true;
            position = slide ? to - Math.sign(to - position) : to;
            cut = false;
        }
        page = to;
        position = to;
    }

    Behavior on position {
        enabled: !pager.cut

        NumberAnimation {
            duration: 250
            easing.type: Easing.OutExpo
        }
    }
}
