pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// Networks first set up with a password from the network panel, until their
// first connection settles. One that fails is forgotten, so NetworkManager
// never retries a wrong key, and the module that started the join opens its
// panel to ask for the password again. Kept here rather than in the panel,
// which may close before the join settles.
Singleton {
    id: root

    property list<WifiNetwork> pending: []
    // Pending networks back to disconnected, waiting a moment for the reason.
    property list<WifiNetwork> failing: []
    // By SSID, the bar module each join started from.
    property var origins: ({})
    // By SSID, why the last join failed, until the panel shows it and closes.
    property var failures: ({})

    signal failed(Item origin)

    function join(network, psk, origin) {
        clear();
        origins = Object.assign({}, origins, {
            [network.name]: origin
        });
        pending = [...pending, network];
        network.connectWithPsk(psk);
    }

    function clear() {
        failures = {};
    }

    function settle(network, failure) {
        if (!pending.includes(network))
            return;
        pending = pending.filter(n => n !== network);
        failing = failing.filter(n => n !== network);
        const origin = origins[network.name] ?? null;
        const remaining = Object.assign({}, origins);
        delete remaining[network.name];
        origins = remaining;
        if (failure === "")
            return;
        network.forget();
        failures = Object.assign({}, failures, {
            [network.name]: failure
        });
        failed(origin);
    }

    Instantiator {
        model: root.pending

        Connections {
            required property WifiNetwork modelData
            // A failure is a return to disconnected once connecting has begun.
            property bool started: false

            target: modelData

            function onStateChanged() {
                if (modelData.connected)
                    root.settle(modelData, "");
                else if (modelData.state === ConnectionState.Connecting)
                    started = true;
                else if (started && modelData.state === ConnectionState.Disconnected) {
                    root.failing = [...root.failing, modelData];
                    reasonless.restart();
                }
            }

            function onConnectionFailed(reason) {
                root.settle(modelData, reason === ConnectionFailReason.NoSecrets || reason === ConnectionFailReason.WifiAuthTimeout ? "Wrong password" : "Could not connect");
            }
        }
    }

    // NetworkManager names no reason for some failures, a timed-out
    // association among them.
    Timer {
        id: reasonless

        interval: 1000
        onTriggered: [...root.failing].forEach(n => root.settle(n, "Could not connect"))
    }
}
