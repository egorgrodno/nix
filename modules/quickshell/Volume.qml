import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// The default source's mute state, then the default sink's volume. Scroll
// steps by 5 up to 100%.
Pill {
    id: volume

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property int level: Math.round((sink?.audio.volume ?? 0) * 100)
    readonly property bool muted: sink?.audio.muted ?? false

    // Waybar matches the sink against these port names in order, and only a
    // name with icons of its own changes the glyph from the default speaker.
    readonly property var ports: ["headphone", "speaker", "hdmi", "headset", "hands-free", "portable", "car", "hifi", "phone"]
    readonly property var icons: ({
            headset: [" ", " ", " "],
            phone: [" ", " ", " "],
            portable: [" ", " ", " "],
            car: [" ", " ", " "],
            default: ["", "", ""]
        })
    readonly property string icon: {
        const name = [sink?.name, sink?.properties["device.icon-name"], sink?.properties["device.form-factor"]].join(" ").toLowerCase();
        const set = icons[ports.find(p => name.includes(p))];
        if (!set && muted)
            return "";
        return (set ?? icons.default)[Math.min(Math.trunc(level / 33), 2)];
    }

    text: `${source?.audio.muted ? "󰍭" : ""}    ${icon}  ${level}%`
    tooltip: sink?.description ?? ""
    onClicked: button => {
        if (button === Qt.LeftButton)
            Quickshell.execDetached([Programs.pwvucontrol]);
    }
    onScrolled: steps => {
        if (!sink?.audio)
            return;
        const target = Math.max(0, Math.min(100, level + 5 * steps));
        if (target !== level)
            sink.audio.volume += (target - level) / 100;
    }

    PwObjectTracker {
        objects: [volume.sink, volume.source]
    }
}
