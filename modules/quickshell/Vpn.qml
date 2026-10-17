pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// NetworkManager's VPN and WireGuard profiles, through nmcli, since
// Quickshell's Networking has no VPN type. Re-read whenever nmcli's monitor
// reports a change.
Singleton {
    id: root

    // As {name, uuid, type, state}, with nmcli's type and state: "activated",
    // "activating", "deactivating", or "" while down.
    property var profiles: []
    readonly property var active: profiles.filter(p => p.state === "activated")
    // By uuid, while a switch runs, the state it asked for.
    property var pending: ({})
    // By uuid, why the last switch failed, until the next one.
    property var errors: ({})

    function isUp(profile) {
        return pending[profile.uuid] ?? profile.state !== "";
    }

    function setUp(uuid, up) {
        if (uuid in pending)
            return;
        pending = Object.assign({}, pending, {
            [uuid]: up
        });
        const errors = Object.assign({}, root.errors);
        delete errors[uuid];
        root.errors = errors;
        switcher.createObject(root, {
            uuid: uuid,
            command: [Programs.nmcli, "connection", up ? "up" : "down", "uuid", uuid]
        });
    }

    function refresh() {
        settle.restart();
    }

    Component {
        id: switcher

        Process {
            id: process

            required property string uuid

            running: true
            stderr: StdioCollector {
                id: message
            }
            onExited: code => {
                if (code !== 0)
                    root.errors = Object.assign({}, root.errors, {
                        [uuid]: message.text.trim().split("\n").pop().replace(/^Error: /, "")
                    });
                const pending = Object.assign({}, root.pending);
                delete pending[uuid];
                root.pending = pending;
                root.refresh();
                process.destroy();
            }
        }
    }

    // Unescaped, so a colon in a name splits it, but only the name: the
    // fields after it never hold one.
    Process {
        id: list

        command: [Programs.nmcli, "--terse", "--escape", "no", "--fields", "NAME,UUID,TYPE,STATE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: root.profiles = text.split("\n").filter(l => l !== "").map(l => {
                const fields = l.split(":");
                const state = fields.pop();
                const type = fields.pop();
                const uuid = fields.pop();
                return {
                    name: fields.join(":"),
                    uuid: uuid,
                    type: type,
                    state: state
                };
            }).filter(p => p.type === "vpn" || p.type === "wireguard")
        }
    }

    // nmcli prints a line per event, several for one change.
    Timer {
        id: settle

        interval: 300
        running: true
        onTriggered: {
            if (list.running)
                settle.restart();
            else
                list.running = true;
        }
    }

    Process {
        id: monitor

        running: true
        command: [Programs.nmcli, "monitor"]
        stdout: SplitParser {
            onRead: root.refresh()
        }
        // NetworkManager restarted, or nmcli died with it.
        onExited: retry.start()
    }

    Timer {
        id: retry

        interval: 5000
        onTriggered: monitor.running = true
    }
}
