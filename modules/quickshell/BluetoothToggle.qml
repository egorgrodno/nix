import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

// Bluetooth off in grey, on in white, and in blue while a device is connected.
// Off soft-blocks every Bluetooth radio through rfkill. On the thinkpad that
// cuts the radio's power and BlueZ drops the adapter, so the module shows
// wherever there is an rfkill switch or an adapter. Right-click opens
// blueman-manager.
Pill {
    id: bluetooth

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    // Each Bluetooth rfkill switch by index, as {soft, hard}.
    property var switches: ({})
    readonly property bool hardBlocked: Object.values(switches).some(s => s.hard)
    readonly property bool powered: adapter?.enabled ?? false
    // While a toggle settles, the state it asked for.
    property bool busy: false
    property bool target
    readonly property bool shownOn: busy ? target : powered
    readonly property var connected: Bluetooth.devices.values.filter(d => d.connected)

    function toggle() {
        if (switcher.running || hardBlocked)
            return;
        target = !shownOn;
        busy = true;
        settle.restart();
        switcher.command = [Programs.rfkill, target ? "unblock" : "block", "bluetooth"];
        switcher.running = true;
        power();
    }

    // BlueZ powers an adapter as it appears, but one it had off before the
    // block, or one powered off without a block, stays off.
    function power() {
        if (busy && target && adapter?.state === BluetoothAdapterState.Disabled)
            adapter.enabled = true;
    }

    visible: adapter !== null || Object.keys(switches).length > 0
    tooltip: {
        if (hardBlocked)
            return "Bluetooth blocked by a hardware switch";
        if (!shownOn)
            return "Bluetooth off";
        if (connected.length === 0)
            return "Bluetooth on";
        return connected.map(d => d.batteryAvailable ? `${d.name}: ${Math.round(d.battery * 100)}%` : d.name).join("\n");
    }
    onPoweredChanged: if (busy && powered === target)
        busy = false
    onAdapterChanged: power()
    onClicked: button => {
        if (button === Qt.LeftButton)
            toggle();
        else if (button === Qt.RightButton)
            Launcher.run([Programs.bluemanManager]);
    }

    // A slot as wide as the widest glyph, measured as on the volume module.
    BarText {
        id: glyphs

        visible: false
        text: "\u{F00AF}\n\u{F00B1}\n\u{F00B2}"
    }

    BarText {
        anchors.verticalCenter: parent.verticalCenter
        width: glyphs.implicitWidth
        horizontalAlignment: Text.AlignHCenter
        text: !bluetooth.shownOn ? "\u{F00B2}" : bluetooth.connected.length > 0 ? "\u{F00B1}" : "\u{F00AF}"
        color: !bluetooth.shownOn ? Theme.foregroundDark : bluetooth.connected.length > 0 ? Theme.blue : "#ffffff"
    }

    Connections {
        target: bluetooth.adapter

        function onStateChanged() {
            bluetooth.power();
        }
    }

    Process {
        id: switcher
    }

    // Every rfkill switch on start, then each change. Type 2 is Bluetooth, and
    // op 1 removes a switch.
    Process {
        running: true
        command: [Programs.rfkill, "event"]
        stdout: SplitParser {
            onRead: line => {
                const m = line.match(/idx (\d+) type (\d+) op (\d+) soft (\d+) hard (\d+)/);
                if (!m || m[2] !== "2")
                    return;
                const switches = Object.assign({}, bluetooth.switches);
                if (m[3] === "1")
                    delete switches[m[1]];
                else
                    switches[m[1]] = {
                        soft: m[4] === "1",
                        hard: m[5] === "1"
                    };
                bluetooth.switches = switches;
            }
        }
    }

    Timer {
        id: settle

        interval: 5000
        onTriggered: bluetooth.busy = false
    }
}
