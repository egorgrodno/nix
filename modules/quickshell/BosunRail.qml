pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls.Basic
import Quickshell

// The sidebar collapsed: Waiting on you with how many wait, the desk, a tile
// per session, and the Log at the foot. The sessions scroll between the two
// rules once they outgrow the rail. A tile shows a state and a name cut to
// fit, and its tooltip the rest.
Item {
    id: rail

    // The selected row's key, as BosunSidebar names them.
    property string selected
    // Lights the selected tile's edge while the keyboard is here.
    readonly property bool focused: activeFocus
    // What the tooltips' ages count from.
    property real now: Date.now()

    // A tile's row picked: "waiting", "desk", "session:<node>" or "log".
    signal picked(string key)

    width: 76

    onSelectedChanged: revealing.restart()

    Timer {
        running: rail.visible
        interval: 30000
        repeat: true
        triggeredOnStart: true
        onTriggered: rail.now = Date.now()
    }

    // Once the tiles have laid out. A timer rather than Qt.callLater, which
    // outlives the rail.
    Timer {
        id: revealing

        interval: 0
        onTriggered: {
            const index = Bosun.tree.findIndex(s => `session:${s.node}` === rail.selected);
            if (index >= 0)
                sessions.positionViewAtIndex(index, ListView.Contain);
        }
    }

    Tile {
        y: 10
        glyph: BosunLook.states.blocked.glyph
        count: Bosun.mine.length
        inert: count === 0
        current: rail.selected.startsWith("decision:")
        tip: count === 0 ? "Nothing waits" : count === 1 ? "1 decision waits on you" : `${count} decisions wait on you`
        onTapped: rail.picked("waiting")
    }

    Tile {
        y: 54
        glyph: Bosun.desk ? BosunLook.desk : BosunLook.master
        dot: BosunKept.deskUnread ? Theme.blue : "transparent"
        current: rail.selected === "desk"
        tip: Bosun.desk ? BosunKept.deskUnread ? "Front desk: a reply you have not seen" : "Front desk" : "Desk: the master, until there is a desk"
        onTapped: rail.picked("desk")
    }

    Rule {
        y: 104
    }

    ListView {
        id: sessions

        y: 110
        width: parent.width
        height: parent.height - y - 66
        clip: true
        spacing: 4
        boundsBehavior: Flickable.StopAtBounds
        // No tiles while the sidebar shows instead.
        model: ScriptModel {
            values: rail.visible ? Bosun.tree : []
            objectProp: "node"
        }

        ScrollBar.vertical: OverlayScrollBar {}

        header: Item {
            height: 4
        }

        delegate: Tile {
            id: tile

            required property var modelData
            readonly property var session: Bosun.sessions.find(s => s.node === modelData.node) ?? modelData

            stateKey: BosunLook.stateOf(session)
            label: modelData.node
            dot: Bosun.mine.some(d => d.node === modelData.node) ? Theme.yellow : "transparent"
            current: rail.selected === `session:${modelData.node}`
            tipContent: Column {
                spacing: 4

                Row {
                    spacing: 8

                    BarText {
                        id: tipName

                        text: tile.modelData.node
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }

                    Caption {
                        anchors.baseline: tipName.baseline
                        text: {
                            const s = tile.session;
                            return [BosunLook.stateWords(s), BosunLook.age(s.activity?.at, rail.now), s.effort, s.context ? BosunLook.tokens(s.context.used) : ""].filter(w => w).join(" · ");
                        }
                    }
                }

                Caption {
                    visible: text !== ""
                    width: Math.min(implicitWidth, 420)
                    elide: Text.ElideRight
                    text: tile.session.activity ? BosunLook.activityText(tile.session.activity).split("\n")[0] : ""
                }
            }
            onTapped: rail.picked(`session:${modelData.node}`)
        }
    }

    Rule {
        anchors.bottom: logTile.top
        anchors.bottomMargin: 10
    }

    Tile {
        id: logTile

        anchors.bottom: parent.bottom
        anchors.bottomMargin: 10
        glyph: BosunLook.history
        current: rail.selected.startsWith("log:")
        tip: `Log: ${Bosun.logToday} today`
        onTapped: rail.picked("log")
    }

    // Between the ends and the sessions.
    component Rule: Rectangle {
        x: 22
        width: 32
        height: 1
        color: Theme.tint(0.12)
    }

    // A glyph, and under it a name cut to fit, with a yellow count while any
    // wait, or a dot.
    component Tile: BosunRow {
        id: tile

        // A session's state, or a glyph of its own, lit with the tile.
        property string stateKey
        property string glyph
        property string label
        property int count: 0
        property color dot: "transparent"
        property string tip
        property Component tipContent: null

        // As wide as the rail, its fill inset: ListView puts a delegate at
        // x 0.
        width: rail.width
        height: label !== "" ? 50 : 40
        inset: 8
        focused: rail.focused
        // The edge sits at the rail's own left.
        edgeOffset: -inset

        BosunStateGlyph {
            anchors.horizontalCenter: parent.horizontalCenter
            y: tile.label !== "" ? 6 : (tile.height - height) / 2
            stateKey: tile.stateKey
            text: tile.glyph !== "" ? tile.glyph : BosunLook.states[tile.stateKey]?.glyph ?? ""
            tint: tile.stateKey !== "" ? BosunLook.stateColor(tile.stateKey) : tile.current || tile.hovered && !tile.inert ? Theme.foregroundStrong : tile.inert ? Theme.foregroundFaint : Theme.foregroundMuted
            font.pixelSize: 18
        }

        BarText {
            x: tile.inset + 2
            y: 30
            width: parent.width - 2 * x
            visible: tile.label !== ""
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: tile.label
            color: tile.current ? Theme.foregroundStrong : Theme.foregroundMuted
            font.pixelSize: 11
        }

        BosunBadge {
            x: tile.inset + 36
            y: 3
            count: tile.count
            pixelSize: 10
        }

        Rectangle {
            x: tile.inset + 40
            y: 5
            visible: tile.dot.a > 0
            width: 7
            height: 7
            radius: 3.5
            color: tile.dot
        }

        Tooltip {
            target: tile
            beside: true
            text: tile.tip
            content: tile.tipContent
            hovered: tile.hovered
        }
    }
}
