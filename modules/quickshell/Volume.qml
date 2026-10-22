import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// The default source's mute state, then the default sink's volume, each glyph
// red while muted. Scroll steps by 5 up to 100%.
Pill {
    id: volume

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property int level: Math.round((sink?.audio.volume ?? 0) * 100)
    readonly property bool muted: sink?.audio.muted ?? false

    // The sink is matched against these port names in order, and only a name
    // with icons of its own changes the glyph from the default speaker.
    readonly property var ports: ["headphone", "speaker", "hdmi", "headset", "hands-free", "portable", "car", "hifi", "phone"]
    readonly property var icons: ({
            headset: [" ", " ", " "],
            phone: [" ", " ", " "],
            portable: [" ", " ", " "],
            car: [" ", " ", " "],
            default: ["", "", ""]
        })
    // The sink's own icons, or null for the default speaker's.
    readonly property var portIcons: {
        const name = [sink?.name, sink?.properties["device.icon-name"], sink?.properties["device.form-factor"]].join(" ").toLowerCase();
        return icons[ports.find(p => name.includes(p))] ?? null;
    }
    readonly property string icon: !portIcons && muted ? "\uEEE8" : (portIcons ?? icons.default)[Math.min(Math.trunc(level / 33), 2)]

    tooltip: sink?.description ?? ""
    onClicked: button => {
        if (button === Qt.LeftButton)
            Launcher.run([Programs.pwvucontrol]);
    }
    onScrolled: steps => {
        if (!sink?.audio)
            return;
        const target = Math.max(0, Math.min(100, level + 5 * steps));
        if (target !== level)
            sink.audio.volume += (target - level) / 100;
    }

    // Each glyph gets a slot as wide as the widest it can show, so a level or
    // mute change never resizes the module. FontMetrics gives these glyphs one
    // advance, so hidden Texts measure them, as wide as their widest line.
    BarText {
        id: micGlyphs

        visible: false
        text: "\u{F036D}\n\uEC1C"
    }

    BarText {
        id: speakerGlyphs

        visible: false
        text: (volume.portIcons ?? volume.icons.default.concat(["\uEEE8"])).join("\n")
    }

    BarText {
        anchors.verticalCenter: parent.verticalCenter
        width: micGlyphs.implicitWidth + 10
        text: volume.source?.audio.muted ? "\u{F036D}" : "\u{EC1C}"
        color: volume.source?.audio.muted ? Theme.red : Theme.foregroundStrong
    }

    BarText {
        anchors.verticalCenter: parent.verticalCenter
        width: speakerGlyphs.implicitWidth
        text: volume.icon
        color: volume.muted ? Theme.red : Theme.foregroundStrong
    }

    Meter {
        anchors.verticalCenter: parent.verticalCenter
        graded: false
        value: volume.level / 100
        fill: volume.muted ? Theme.foregroundFaint : Theme.foregroundMuted
    }

    Figure {
        anchors.verticalCenter: parent.verticalCenter
        widest: "100%"
        text: `${volume.level}%`
        color: volume.muted ? Theme.foregroundMuted : Theme.foregroundStrong
    }

    PwObjectTracker {
        objects: [volume.sink, volume.source]
    }
}
