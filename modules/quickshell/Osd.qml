import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Wayland

// The volume, the microphone's mute, the brightness or Caps Lock, for a second
// after the bind that changed it, centred above the bottom bar on the focused
// screen. Binds raise it, through IPC or a backlight step, rather than change
// signals, so the bar's scroll, pwvucontrol's sliders and the power panel,
// which show the value themselves, do not. It slides out of the bar as it fades
// in, and back, and takes no input.
PanelWindow {
    id: osd

    // "volume", "mic", "brightness" or "caps".
    property string kind: "volume"
    // False from the start of the fade out.
    property bool shown: false
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool muted: sink?.audio.muted ?? false
    readonly property bool micMuted: source?.audio.muted ?? false
    readonly property bool metered: kind === "volume" || kind === "brightness"
    readonly property int percent: kind === "brightness" ? Backlight.percent : Math.round((sink?.audio.volume ?? 0) * 100)
    // Volume's mute greys the meter.
    readonly property bool dimmed: kind === "volume" && muted

    function show(what) {
        kind = what;
        visible = true;
        shown = true;
        hide.restart();
    }

    screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    visible: false
    anchors.bottom: true
    // Reaching into the bar as far as the box slides, as a panel does.
    margins.bottom: Theme.barHeight + Theme.outerGap - Theme.slide
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 300
    implicitHeight: box.height + Theme.slide
    color: "transparent"
    mask: Region {}
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.namespace: "quickshell-osd"

    IpcHandler {
        target: "osd"

        function volume(): void {
            osd.show("volume");
        }

        function mic(): void {
            osd.show("mic");
        }

        // Read once the bind fires, on the key's release, when the lock has
        // already toggled.
        function caps(): void {
            capsLock.update();
        }
    }

    // The brightness keys step the backlight through its own IPC target.
    Connections {
        target: Backlight

        function onStepped() {
            osd.show("brightness");
        }
    }

    CapsLock {
        id: capsLock

        onRead: osd.show("caps")
    }

    Timer {
        id: hide

        interval: 1000
        onTriggered: osd.shown = false
    }

    PwObjectTracker {
        objects: [osd.sink, osd.source]
    }

    Rectangle {
        id: box

        width: parent.width
        height: 48
        y: osd.shown ? 0 : Theme.slide
        opacity: osd.shown ? 1 : 0
        color: Theme.alpha(Theme.backgroundRaised, 0.97)
        border.color: Theme.tint(0.08)
        border.width: 1
        radius: Theme.radius
        onOpacityChanged: if (!osd.shown && opacity === 0)
            osd.visible = false

        // One curve both ways, as in Panel.qml.
        Behavior on y {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutExpo
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutExpo
            }
        }

        Row {
            x: 16
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 2 * 16
            spacing: 12

            // A slot as wide as the widest glyph, so the meter keeps its
            // length, measured as on the volume module.
            BarText {
                id: glyphs

                visible: false
                font.pixelSize: 20
                text: "\u{F026}\n\u{F027}\n\u{F028}\n\u{EEE8}\n\u{F036D}\n\u{EC1C}\n\u{F00E0}\n\u{F0632}"
            }

            BarText {
                id: glyph

                anchors.verticalCenter: parent.verticalCenter
                width: glyphs.implicitWidth
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: 20
                text: {
                    if (osd.kind === "mic")
                        return osd.micMuted ? "\u{F036D}" : "\u{EC1C}";
                    if (osd.kind === "brightness")
                        return "\u{F00E0}";
                    if (osd.kind === "caps")
                        return "\u{F0632}";
                    return osd.muted ? "\u{EEE8}" : ["\u{F026}", "\u{F027}", "\u{F028}"][Math.min(Math.trunc(osd.percent / 33), 2)];
                }
                // Red while muted, as on the volume module.
                color: {
                    if (osd.kind === "caps")
                        return capsLock.locked ? Theme.blue : Theme.foregroundMuted;
                    if (osd.kind === "mic" && osd.micMuted || osd.dimmed)
                        return Theme.red;
                    return Theme.foregroundStrong;
                }
            }

            Meter {
                anchors.verticalCenter: parent.verticalCenter
                visible: osd.metered
                width: parent.width - glyph.width - percent.width - 2 * parent.spacing
                graded: false
                value: osd.percent / 100
                fill: osd.dimmed ? Theme.foregroundFaint : Theme.blue
            }

            Figure {
                id: percent

                anchors.verticalCenter: parent.verticalCenter
                visible: osd.metered
                horizontalAlignment: Text.AlignRight
                widest: "100%"
                text: `${osd.percent}%`
                color: osd.dimmed ? Theme.foregroundMuted : Theme.foregroundStrong
            }

            BarText {
                anchors.verticalCenter: parent.verticalCenter
                visible: !osd.metered
                text: osd.kind === "mic" ? (osd.micMuted ? "Microphone muted" : "Microphone on") : (capsLock.locked ? "Caps Lock on" : "Caps Lock off")
            }
        }
    }
}
