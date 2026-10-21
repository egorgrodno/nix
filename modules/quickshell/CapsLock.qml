import QtQuick
import Quickshell
import Quickshell.Io

// Caps Lock on Hyprland's main keyboard, as of the last read. Read on the
// key's release, once the lock has toggled.
Scope {
    id: caps

    property bool locked: false

    signal read

    function update() {
        reader.running = true;
    }

    Process {
        id: reader

        command: [Programs.hyprctl, "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                const keyboards = JSON.parse(text).keyboards;
                caps.locked = (keyboards.find(k => k.main) ?? keyboards[0])?.capsLock ?? false;
                caps.read();
            }
        }
    }
}
