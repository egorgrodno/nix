import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland

// At the session's first start, every screen under opaque black, the colour
// Hyprland starts on, until the saved layout has applied and awww has drawn the
// wallpaper after it, or with no wallpaper the layout alone; then it fades out,
// so the scale jump and the first draws happen unseen. Hyprland's pointer,
// hidden from its start, and its black background stay until the fade out
// starts, which gives back the pointer and the theme's background. A bar
// restarted in the same Hyprland instance skips it, a crash under it included,
// and gives both back too. awww's
// daemon, which the session leaves to the bar, starts once it maps, or at once
// without it: a wallpaper drawn first would vanish under it. After 3 s it lifts
// regardless.
Scope {
    id: root

    // From the start until the fade out ends.
    property bool covering: false
    // False from the start of the fade out.
    property bool shown: false
    property bool daemon: false
    // awww's surfaces mapped, one per output.
    property int drawn: 0
    property real start: 0
    // awww maps no surface until it draws, so with no wallpaper only the
    // layout counts.
    readonly property bool ready: Monitors.settled && (Wallpapers.empty || drawn >= Quickshell.screens.length && !Wallpapers.settling)

    function startDaemon() {
        if (daemon)
            return;
        daemon = true;
        Quickshell.execDetached([Programs.systemctl, "--user", "start", "awww.service"]);
    }

    // The pointer through Hyprland's option, as it never enters a surface that
    // maps under it until it moves.
    function setHyprland(covered) {
        const background = covered ? "000000" : Theme.backgroundDesktop.toString().slice(1);
        Quickshell.execDetached([Programs.hyprctl, "eval", `hl.config({ cursor = { invisible = ${covered} }, misc = { background_color = "rgba(${background}ff)" } })`]);
    }

    // For the journal.
    function waiting() {
        const awww = !Wallpapers.empty;
        return [Monitors.settled ? "" : "the layout", !awww || drawn >= Quickshell.screens.length ? "" : `awww on ${Quickshell.screens.length - drawn} more screens`, awww && Wallpapers.settling ? "the wallpaper's redraw" : ""].filter(s => s !== "").join(", ");
    }

    function lift(reason) {
        if (!shown)
            return;
        shown = false;
        hold.stop();
        timeout.stop();
        setHyprland(false);
        console.info(`Curtain: lifted after ${Date.now() - start} ms, ${reason}`);
    }

    onReadyChanged: {
        if (ready)
            hold.restart();
        else
            hold.stop();
    }

    // The last cover's Hyprland instance.
    FileView {
        id: marker

        path: Quickshell.statePath("curtain")
        blockAllReads: true
        blockWrites: true
        printErrors: false
    }

    Component.onCompleted: {
        const instance = Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? "";
        if (marker.text().trim() === instance) {
            setHyprland(false);
            startDaemon();
            return;
        }
        marker.setText(instance);
        start = Date.now();
        setHyprland(true);
        // First, so the cover starts opaque rather than fading in.
        shown = true;
        covering = true;
        timeout.start();
    }

    Variants {
        model: root.covering ? Quickshell.screens : []

        PanelWindow {
            required property ShellScreen modelData

            screen: modelData
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            exclusionMode: ExclusionMode.Ignore
            color: "transparent"
            // Clicks pass through from the start of the fade out.
            mask: Region {
                item: root.shown ? cover : null
            }
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "quickshell-curtain"

            // The first frame maps the cover. Hyprland's `openlayer` can come
            // before the bar, just started, listens.
            Connections {
                target: cover.Window.window
                enabled: !root.daemon

                function onFrameSwapped() {
                    root.startDaemon();
                }
            }

            Rectangle {
                id: cover

                anchors.fill: parent
                color: "black"
                opacity: root.shown ? 1 : 0
                onOpacityChanged: if (!root.shown && opacity === 0)
                    root.covering = false

                Behavior on opacity {
                    NumberAnimation {
                        duration: 600
                        easing.type: Easing.InOutQuad
                    }
                }
            }
        }
    }

    Connections {
        target: Hyprland
        enabled: root.shown

        function onRawEvent(event) {
            if (event.name === "openlayer" && event.data === "awww-daemon")
                root.drawn++;
        }
    }

    // awww draws a moment after `img` returns, and the redraw a layout sets off
    // starts only as its timer ends.
    Timer {
        id: hold

        interval: 100
        onTriggered: root.lift("ready")
    }

    // Starting the daemon too, should no cover have drawn.
    Timer {
        id: timeout

        interval: 3000
        onTriggered: {
            root.startDaemon();
            root.lift(`timed out waiting for ${root.waiting()}`);
        }
    }
}
