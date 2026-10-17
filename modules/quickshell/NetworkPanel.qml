import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Networking as Nm

// Under the network module: the connection, Wi-Fi and the networks in range,
// Ethernet, and a switch per VPN profile.
Panel {
    id: panel

    readonly property Nm.WifiDevice wifi: module.wifi
    readonly property Nm.WiredDevice wired: module.wired
    // Connected first, then any whose join just failed, so its password field
    // shows, then known, then by the module's strength steps, so a wavering
    // signal does not reorder the list under the pointer.
    readonly property var networks: (wifi?.networks.values ?? []).filter(n => n.name !== "").sort((a, b) => b.connected - a.connected || (b.name in WifiJoin.failures) - (a.name in WifiJoin.failures) || b.known - a.known || module.bars(b.signalStrength) - module.bars(a.signalStrength) || a.name.localeCompare(b.name))

    function openEditor(args) {
        Quickshell.execDetached([Programs.nmConnectionEditor].concat(args));
        close();
    }

    // Quickshell lists a network it does not know only while scanning, so the
    // scanner, which the module starts, runs as long as the panel is open.
    Component.onCompleted: Vpn.refresh()
    Component.onDestruction: {
        if (wifi)
            wifi.scannerEnabled = false;
        WifiJoin.clear();
    }

    // A small button, lit while `lit` is set, as a confirmation waits.
    component Action: Rectangle {
        id: action

        property alias text: label.text
        property color hoverFill: Qt.rgba(1, 1, 1, 0.12)
        property bool lit: false

        signal clicked

        width: label.implicitWidth + 20
        height: 28
        radius: Theme.radius - 4
        color: lit || actionMouse.containsMouse ? hoverFill : Qt.rgba(1, 1, 1, 0.06)

        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        BarText {
            id: label

            anchors.centerIn: parent
            color: action.enabled ? "#ffffff" : Theme.foregroundMuted
            font.pixelSize: 14
        }

        MouseArea {
            id: actionMouse

            anchors.fill: parent
            hoverEnabled: true
            onClicked: action.clicked()
        }
    }

    // A title over a muted line, with a control on the right. A clickable one
    // takes clicks across the whole row.
    component Labelled: Item {
        id: labelled

        property alias title: titleText.text
        property alias detail: detailText.text
        property alias detailColor: detailText.color
        property bool clickable: false
        readonly property alias hovered: rowMouse.containsMouse
        default property alias control: controlSlot.data

        signal clicked

        height: Math.max(texts.implicitHeight, controlSlot.height)

        MouseArea {
            id: rowMouse

            anchors.fill: parent
            enabled: labelled.clickable
            hoverEnabled: true
            onClicked: labelled.clicked()
        }

        Column {
            id: texts

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - controlSlot.width - 12
            spacing: 4

            BarText {
                id: titleText

                width: parent.width
                elide: Text.ElideRight
            }

            BarText {
                id: detailText

                width: parent.width
                visible: text !== ""
                elide: Text.ElideRight
                color: Theme.foregroundMuted
                font.pixelSize: 14
            }
        }

        Item {
            id: controlSlot

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: childrenRect.width
            height: childrenRect.height
        }
    }

    // A network in range: a click connects, or asks for the password a new WPA
    // network needs. On hover, the connected network offers Disconnect, one
    // connecting Stop, and a known one Forget, which takes a second click.
    component NetworkRow: Column {
        id: row

        required property Nm.WifiNetwork modelData
        required property string glyph
        // The bar module whose panel reopens if a join fails.
        property Item origin
        readonly property bool psk: [Nm.WifiSecurityType.WpaPsk, Nm.WifiSecurityType.Wpa2Psk, Nm.WifiSecurityType.Sae].includes(modelData.security)
        readonly property bool open: [Nm.WifiSecurityType.Open, Nm.WifiSecurityType.Owe].includes(modelData.security)
        readonly property bool connecting: modelData.state === Nm.ConnectionState.Connecting
        // Why a join from the panel failed, which forgot the network.
        readonly property string joinFailure: WifiJoin.failures[modelData.name] ?? ""
        property bool asking: joinFailure !== ""
        property bool armed: false
        property string failure: ""

        // For enterprise and WEP networks, which only the editor sets up.
        signal editorWanted

        function activate() {
            if (modelData.connected || modelData.stateChanging)
                return;
            failure = "";
            if (modelData.known || open)
                modelData.connect();
            else if (psk)
                asking = !asking;
            else
                editorWanted();
        }

        function submit() {
            if (password.text.length < 8)
                return;
            failure = "";
            asking = false;
            if (modelData.known)
                modelData.connectWithPsk(password.text);
            else
                WifiJoin.join(modelData, password.text, origin);
            password.text = "";
        }

        Component.onCompleted: if (asking)
            password.forceActiveFocus()
        onJoinFailureChanged: if (joinFailure !== "")
            asking = true
        onAskingChanged: if (asking)
            password.forceActiveFocus()

        Item {
            width: row.width
            height: 40

            Rectangle {
                anchors.fill: parent
                radius: Theme.radius - 4
                color: hover.hovered ? Qt.rgba(1, 1, 1, 0.07) : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: 150
                        easing.type: Easing.OutQuad
                    }
                }
            }

            HoverHandler {
                id: hover
            }

            MouseArea {
                anchors.fill: parent
                onClicked: row.activate()
            }

            BarText {
                id: strength

                x: 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.glyph
                color: row.modelData.connected ? Theme.blue : "#ffffff"
                font.pixelSize: 18
            }

            BarText {
                anchors.left: strength.right
                anchors.leftMargin: 10
                anchors.right: side.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: row.modelData.name
                elide: Text.ElideRight
                color: row.modelData.connected ? Theme.blue : "#ffffff"
            }

            Row {
                id: side

                readonly property bool acting: hover.hovered && (row.modelData.connected || row.modelData.known || row.connecting)

                anchors.right: parent.right
                anchors.rightMargin: 6
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                BarText {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: !side.acting
                    rightPadding: 4
                    text: {
                        const n = row.modelData;
                        if (n.stateChanging)
                            return n.state === Nm.ConnectionState.Disconnecting ? "Disconnecting…" : "Connecting…";
                        if (n.connected)
                            return "Connected";
                        if (n.known)
                            return "Saved";
                        return row.open ? "" : "\u{F033E}";
                    }
                    color: Theme.foregroundMuted
                    font.pixelSize: 14
                }

                Action {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: side.acting && row.connecting
                    text: "Stop"
                    onClicked: row.modelData.device.disconnect()
                }

                Action {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: side.acting && row.modelData.connected
                    text: "Disconnect"
                    onClicked: row.modelData.disconnect()
                }

                Action {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: side.acting && row.modelData.known
                    text: row.armed ? "Forget?" : "Forget"
                    hoverFill: Theme.alpha(Theme.red, 0.5)
                    lit: row.armed
                    onClicked: {
                        if (row.armed) {
                            row.armed = false;
                            row.modelData.forget();
                        } else {
                            row.armed = true;
                            disarm.restart();
                        }
                    }
                }
            }

            Timer {
                id: disarm

                interval: 3000
                onTriggered: row.armed = false
            }
        }

        Row {
            x: 8
            visible: row.asking
            topPadding: 4
            bottomPadding: 8
            spacing: 8

            TextField {
                id: password

                width: row.width - 16 - connectButton.width - parent.spacing
                height: 28
                leftPadding: 8
                rightPadding: 8
                topPadding: 0
                bottomPadding: 0
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                placeholderText: "Password"
                placeholderTextColor: Theme.foregroundMuted
                color: "#ffffff"
                selectionColor: Theme.blue
                selectedTextColor: Theme.backgroundMain
                font.family: Theme.fontUI
                font.pixelSize: 14
                onAccepted: row.submit()

                background: Rectangle {
                    radius: Theme.radius - 4
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: password.activeFocus ? Theme.blue : Qt.rgba(1, 1, 1, 0.12)
                }
            }

            Action {
                id: connectButton

                enabled: password.text.length >= 8
                text: "Connect"
                onClicked: row.submit()
            }
        }

        BarText {
            x: 8
            visible: text !== ""
            bottomPadding: 8
            text: row.failure !== "" ? row.failure : row.joinFailure
            color: Theme.yellow
            font.pixelSize: 14
        }

        Connections {
            target: row.modelData

            function onConnectionFailed(reason) {
                if (reason === Nm.ConnectionFailReason.NoSecrets && row.psk) {
                    row.failure = "Wrong password";
                    row.asking = true;
                } else
                    row.failure = "Could not connect";
            }
        }
    }

    Row {
        spacing: 12

        BarText {
            anchors.verticalCenter: parent.verticalCenter
            text: panel.module.glyph
            color: panel.module.glyphColor
            font.pixelSize: 32
        }

        Column {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            BarText {
                width: panel.contentWidth - 44
                elide: Text.ElideRight
                text: panel.module.name
            }

            BarText {
                visible: text !== ""
                text: panel.module.detail
                color: Theme.foregroundMuted
                font.pixelSize: 14
            }
        }
    }

    Column {
        width: panel.contentWidth
        visible: panel.wifi !== null
        spacing: 8

        Labelled {
            id: wifiSwitch

            width: parent.width
            title: "Wi-Fi"
            detail: Nm.Networking.wifiHardwareEnabled ? "" : "Blocked by a hardware switch"
            clickable: Nm.Networking.wifiHardwareEnabled
            onClicked: Nm.Networking.wifiEnabled = !Nm.Networking.wifiEnabled

            Toggle {
                checked: Nm.Networking.wifiEnabled
                hovered: wifiSwitch.hovered
            }
        }

        // Six rows, then it scrolls.
        Flickable {
            width: parent.width
            height: Math.min(contentHeight, 6 * 40)
            visible: Nm.Networking.wifiEnabled && panel.networks.length > 0
            contentHeight: list.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: list

                width: parent.width

                Repeater {
                    model: ScriptModel {
                        values: panel.networks
                    }

                    NetworkRow {
                        width: list.width
                        glyph: panel.module.strengthGlyph(modelData.signalStrength)
                        origin: panel.module
                        onEditorWanted: panel.openEditor(["--create", "--type=802-11-wireless"])
                    }
                }
            }
        }

        BarText {
            visible: Nm.Networking.wifiEnabled && panel.networks.length === 0
            text: "Searching…"
            color: Theme.foregroundMuted
            font.pixelSize: 14
        }
    }

    Labelled {
        width: panel.contentWidth
        visible: panel.wired !== null
        title: "Ethernet"
        detail: {
            const w = panel.wired;
            if (!w)
                return "";
            if (w.connected)
                return w.linkSpeed > 0 ? `Connected · ${w.linkSpeed} Mb/s` : "Connected";
            return w.hasLink ? "Disconnected" : "Cable unplugged";
        }

        Action {
            visible: panel.wired !== null && (panel.wired.connected || panel.wired.network !== null)
            text: panel.wired?.connected ? "Disconnect" : "Connect"
            onClicked: panel.wired.connected ? panel.wired.disconnect() : panel.wired.network.connect()
        }
    }

    Column {
        width: panel.contentWidth
        visible: Vpn.profiles.length > 0
        spacing: 12

        Repeater {
            model: ScriptModel {
                values: Vpn.profiles
                objectProp: "uuid"
            }

            Labelled {
                id: vpn

                required property var modelData
                readonly property bool up: Vpn.isUp(modelData)
                readonly property string error: Vpn.errors[modelData.uuid] ?? ""

                width: panel.contentWidth
                title: modelData.name
                detail: {
                    if (error !== "")
                        return error;
                    switch (modelData.state) {
                    case "activating":
                        return "Connecting…";
                    case "deactivating":
                        return "Disconnecting…";
                    default:
                        return modelData.type === "wireguard" ? "WireGuard" : "VPN";
                    }
                }
                detailColor: error !== "" ? Theme.yellow : Theme.foregroundMuted
                clickable: !(modelData.uuid in Vpn.pending)
                onClicked: Vpn.setUp(modelData.uuid, !up)

                Toggle {
                    checked: vpn.up
                    hovered: vpn.hovered
                }
            }
        }
    }

    Rectangle {
        width: panel.contentWidth
        height: 36
        radius: Theme.radius - 4
        color: settingsMouse.containsMouse ? Qt.rgba(1, 1, 1, 0.1) : Qt.rgba(1, 1, 1, 0.05)

        Behavior on color {
            ColorAnimation {
                duration: 150
                easing.type: Easing.OutQuad
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: 8

            BarText {
                anchors.verticalCenter: parent.verticalCenter
                text: "\u{F08BB}"
                color: Theme.foregroundMuted
            }

            BarText {
                anchors.verticalCenter: parent.verticalCenter
                text: "Network settings"
                font.pixelSize: 14
            }
        }

        MouseArea {
            id: settingsMouse

            anchors.fill: parent
            hoverEnabled: true
            onClicked: panel.openEditor([])
        }
    }
}
