import QtQuick
import QtQuick.Controls.Basic

// A detail pane of the bosun panel: a title with its facts under it and its
// actions beside it, a body that scrolls, and a foot held at the bottom.
Item {
    id: pane

    property string title
    // Small, at the top right: a decision's id.
    property string aside
    default property alias body: bodyColumn.data
    property alias facts: factRow.data
    property alias actions: actionRow.data
    property alias foot: footColumn.data
    readonly property real bodyWidth: bodyColumn.width
    // What BosunKept keeps the body's scroll under, or "" to keep none.
    property string scrollKey: ""
    // Until the scroll is restored, it is not kept.
    property bool restoring: false

    function restoreScroll() {
        restoring = true;
        restorer.restart();
    }

    onScrollKeyChanged: restoreScroll()
    Component.onCompleted: restoreScroll()

    // Once the body has laid out for the key. A timer rather than
    // Qt.callLater, which outlives the pane.
    Timer {
        id: restorer

        interval: 0
        onTriggered: {
            scroller.contentY = Math.max(0, Math.min(BosunKept.scroll(pane.scrollKey) ?? 0, scroller.contentHeight - scroller.height));
            pane.restoring = false;
        }
    }

    BarText {
        id: titleText

        x: 28
        y: 22
        width: actionRow.x - x - 16
        elide: Text.ElideRight
        text: pane.title
        font.pixelSize: 20
        font.weight: Font.DemiBold
    }

    Row {
        id: actionRow

        anchors.right: asideText.visible ? asideText.left : parent.right
        anchors.rightMargin: asideText.visible ? 16 : 28
        anchors.verticalCenter: titleText.verticalCenter
        spacing: 8
    }

    Caption {
        id: asideText

        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.top: titleText.top
        visible: text !== ""
        text: pane.aside
    }

    Row {
        id: factRow

        x: 28
        anchors.top: titleText.bottom
        anchors.topMargin: 8
        spacing: 18
    }

    Flickable {
        id: scroller

        x: 28
        anchors.top: factRow.bottom
        anchors.topMargin: 20
        anchors.bottom: footColumn.top
        anchors.bottomMargin: footColumn.height > 0 ? 16 : 0
        width: parent.width - 2 * x
        contentHeight: bodyColumn.implicitHeight
        clip: true
        interactive: contentHeight > height
        boundsBehavior: Flickable.StopAtBounds
        onContentYChanged: if (!pane.restoring && pane.scrollKey !== "")
            BosunKept.keepScroll(pane.scrollKey, contentY)

        ScrollBar.vertical: ScrollBar {
            policy: scroller.interactive ? ScrollBar.AlwaysOn : ScrollBar.AlwaysOff

            contentItem: Rectangle {
                implicitWidth: 4
                radius: 2
                color: Theme.tint(0.25)
            }
        }

        Column {
            id: bodyColumn

            width: scroller.width - (scroller.interactive ? 14 : 0)
            spacing: 16
        }
    }

    Column {
        id: footColumn

        x: 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 20
        width: parent.width - 2 * x
        spacing: 14
    }
}
