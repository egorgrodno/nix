import QtQuick

// Short facts on one line between dots, each a string or {text, color,
// prefix, suffix, separator, widest}: a reading takes a mono slot as wide as
// `widest`, so the line keeps its width as the reading changes, between its
// prefix and suffix in the UI face. A slot sets its reading right, but the
// last one without a suffix left, where the room it leaves falls past the end
// of the line. An empty fact is left out.
Row {
    id: facts

    property var parts: []
    property int size: 14
    property color color: Theme.foregroundMuted
    readonly property var shown: parts.filter(p => (p?.text ?? p ?? "") !== "")
    // Where every fact's baseline sits, whichever face it is set in.
    readonly property real line: Math.ceil(Math.max(ui.ascent, mono.ascent))

    visible: shown.length > 0

    FontMetrics {
        id: ui

        font.family: Theme.fontUI
        font.pixelSize: facts.size
        font.hintingPreference: Font.PreferFullHinting
    }

    FontMetrics {
        id: mono

        font.family: Theme.fontMono
        font.pixelSize: facts.size
        font.hintingPreference: Font.PreferFullHinting
    }

    Repeater {
        model: facts.shown

        Item {
            id: fact

            required property var modelData
            required property int index
            readonly property string widest: modelData.widest ?? ""

            implicitWidth: suffix.x + (suffix.text === "" ? 0 : suffix.width)
            implicitHeight: Math.max(prefix.y + prefix.height, value.y + value.height)

            BarText {
                id: separator

                visible: fact.index > 0
                y: facts.line - baselineOffset
                text: fact.modelData.separator ?? " · "
                color: Theme.foregroundFaint
                font.pixelSize: facts.size
            }

            BarText {
                id: prefix

                x: separator.visible ? separator.width : 0
                y: facts.line - baselineOffset
                text: fact.modelData.prefix ?? ""
                color: facts.color
                font.pixelSize: facts.size
            }

            BarText {
                id: value

                x: prefix.x + (prefix.text === "" ? 0 : prefix.width)
                y: facts.line - baselineOffset
                width: Math.max(implicitWidth, slot.advanceWidth)
                horizontalAlignment: fact.widest === "" || fact.index === facts.shown.length - 1 && !fact.modelData.suffix ? Text.AlignLeft : Text.AlignRight
                text: fact.modelData.text ?? fact.modelData
                color: fact.modelData.color ?? facts.color
                font.family: fact.widest === "" ? Theme.fontUI : Theme.fontMono
                font.pixelSize: facts.size

                TextMetrics {
                    id: slot

                    font: value.font
                    text: fact.widest
                }
            }

            BarText {
                id: suffix

                x: value.x + value.width
                y: facts.line - baselineOffset
                text: fact.modelData.suffix ?? ""
                color: value.color
                font.pixelSize: facts.size
            }
        }
    }
}
