pragma ComponentBehavior: Bound

import QtQuick

// The sidebar shrunk to its sections' glyphs, for the expanded panel: Waiting
// on you with how many wait, the desk with a dot while it holds a reply the
// user has not seen, the Fleet and the Log. A glyph opens its section. At the
// foot, a button shows the whole sidebar beside the rail, or hides it.
Item {
    id: rail

    // The selection's section: "waiting", "desk", "fleet", "log" or "".
    property string section
    property bool sidebarShown: false
    // Lights the section's edge while the keyboard is here.
    readonly property bool focused: activeFocus

    signal picked(string section)
    signal sidebarToggled

    width: 56

    Column {
        x: 8
        y: 12
        spacing: 6

        RailButton {
            name: "waiting"
            glyph: BosunLook.states.blocked.glyph
            tip: "Waiting on you"
            count: Bosun.mine.length
        }

        RailButton {
            name: "desk"
            glyph: BosunLook.desk
            tip: Bosun.desk ? "Front desk" : "Desk: the master, until there is a desk"
            dot: BosunKept.deskUnread
        }

        RailButton {
            name: "fleet"
            glyph: BosunLook.master
            tip: "Fleet"
        }

        RailButton {
            name: "log"
            glyph: BosunLook.history
            tip: "Log"
        }
    }

    RailButton {
        x: 8
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 12
        glyph: BosunLook.dockLeft
        tip: rail.sidebarShown ? "Hide the sidebar" : "Show the sidebar"
        lit: rail.sidebarShown
        onClicked: rail.sidebarToggled()
    }

    // A section's glyph, with a yellow count while any waits, or a blue dot.
    component RailButton: BosunRow {
        id: button

        property string name
        property string glyph
        property string tip
        property int count: 0
        property bool dot: false

        signal clicked

        current: name !== "" && rail.section === name
        focused: rail.focused
        // The edge sits at the rail's own left.
        edgeOffset: -8
        width: 40
        height: 40
        onTapped: name !== "" ? rail.picked(name) : clicked()

        BarText {
            anchors.centerIn: parent
            text: button.glyph
            color: button.lit ? Theme.foregroundStrong : Theme.foregroundMuted
            font.pixelSize: 18
        }

        Rectangle {
            x: parent.width - width - 3
            y: 3
            visible: button.count > 0
            width: Math.max(15, countText.implicitWidth + 6)
            height: 14
            radius: 7
            color: Theme.yellow

            BarText {
                id: countText

                anchors.centerIn: parent
                text: `${button.count}`
                color: Theme.backgroundMain
                font.pixelSize: 10
                font.weight: Font.DemiBold
            }
        }

        Rectangle {
            x: parent.width - 11
            y: 7
            visible: button.dot
            width: 7
            height: 7
            radius: 3.5
            color: Theme.blue
        }

        Tooltip {
            target: button
            text: button.tip
            hovered: button.hovered
        }
    }
}
