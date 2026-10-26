pragma ComponentBehavior: Bound

import QtQuick

// A session's model and effort, one button per value with the current one lit.
// A click switches the session to it and keeps the other; the buttons wait
// until the daemon answers, which a desk in its turn can take 30 s to do.
Column {
    id: root

    required property string node
    required property var session
    readonly property bool waiting: Bosun.switching === node

    width: parent?.width ?? 0
    spacing: 12

    Caption {
        text: root.waiting ? `${BosunLook.chip}  Switching ${root.node}…` : `${BosunLook.chip}  Model and effort`
    }

    Flow {
        width: parent.width
        spacing: 6

        Repeater {
            model: Bosun.models

            Pick {
                required property string modelData

                text: modelData
                lit: modelData === root.session?.model
                onClicked: if (!lit)
                    Bosun.model(root.node, modelData, "")
            }
        }
    }

    Flow {
        width: parent.width
        spacing: 6

        Repeater {
            model: Bosun.efforts

            Pick {
                required property string modelData

                text: modelData
                lit: modelData === root.session?.effort
                onClicked: if (!lit)
                    Bosun.model(root.node, "", modelData)
            }
        }
    }

    component Pick: TextButton {
        height: 30
        enabled: !root.waiting
        hoverFill: lit ? Theme.blue : Theme.tint(0.12)
        textColor: lit ? Theme.backgroundMain : Theme.foregroundStrong
        opacity: enabled ? 1 : 0.5
    }
}
