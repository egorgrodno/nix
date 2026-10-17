pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon. Each notification gets an entry that copies its
// data, so a card keeps its content as it leaves after the notification has
// closed. The server expires nothing itself: each entry runs its own timer.
Singleton {
    id: root

    // Newest first, at most five.
    property list<Entry> popups: []
    // Open panels, registered by Panel.qml: one on the popups' screen holds
    // their timers, since it covers them.
    property var panels: []
    readonly property ShellScreen screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    readonly property bool held: panels.some(p => p.screen === root.screen)

    // dunst's replacement hints, which the scripts send.
    function tagOf(notification) {
        const hints = notification.hints;
        return String(hints["x-dunst-stack-tag"] ?? hints["synchronous"] ?? hints["x-canonical-private-synchronous"] ?? "");
    }

    function remove(entry) {
        popups = popups.filter(e => e !== entry);
        // Once the card has left, which reads it until then.
        entry.destroy(1000);
    }

    component Entry: QtObject {
        id: entry

        // Null once it closes.
        property Notification notification
        property string appName
        property string appIcon
        property string summary
        property string body
        property string image
        property int urgency: NotificationUrgency.Normal
        // A `value` hint from 0 to 100, or -1.
        property int value: -1
        property string tag
        property real expireTimeout: -1
        property bool hovered
        readonly property var actions: notification?.actions ?? []
        // In ms; 0 never expires.
        readonly property int timeout: {
            if (urgency === NotificationUrgency.Critical || expireTimeout === 0)
                return 0;
            if (expireTimeout > 0)
                return expireTimeout;
            return urgency === NotificationUrgency.Low ? 5000 : 15000;
        }

        // Also on an update in place, through `replaces_id` or a tag, which
        // starts the timer over.
        function refresh() {
            const n = notification;
            appName = n.appName;
            appIcon = n.appIcon;
            summary = n.summary;
            body = n.body;
            image = n.image;
            urgency = n.urgency;
            value = n.hints.value === undefined ? -1 : Number(n.hints.value);
            tag = root.tagOf(n);
            expireTimeout = n.expireTimeout;
            if (timer.running)
                timer.restart();
        }

        Component.onCompleted: refresh()

        readonly property Timer timer: Timer {
            interval: entry.timeout
            running: entry.timeout > 0 && !entry.hovered && !root.held
            onTriggered: entry.notification?.expire()
        }

        readonly property Connections connections: Connections {
            target: entry.notification

            function onClosed() {
                root.remove(entry);
            }

            function onSummaryChanged() {
                entry.refresh();
            }

            function onBodyChanged() {
                entry.refresh();
            }

            function onAppIconChanged() {
                entry.refresh();
            }

            function onImageChanged() {
                entry.refresh();
            }

            function onUrgencyChanged() {
                entry.refresh();
            }

            function onHintsChanged() {
                entry.refresh();
            }

            function onExpireTimeoutChanged() {
                entry.refresh();
            }
        }
    }

    Component {
        id: entryComponent

        Entry {}
    }

    NotificationServer {
        keepOnReload: false
        actionsSupported: true
        bodyMarkupSupported: true
        bodyHyperlinksSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: notification => {
            notification.tracked = true;
            const tag = root.tagOf(notification);
            const same = tag === "" ? null : root.popups.find(e => e.tag === tag);
            if (same) {
                // Switched before the old one closes, so its close does not
                // remove the entry.
                const old = same.notification;
                same.notification = notification;
                same.refresh();
                old?.expire();
                return;
            }
            root.popups = [entryComponent.createObject(root, {
                    notification: notification
                }), ...root.popups];
            if (root.popups.length > 5)
                root.popups[5].notification?.expire();
        }
    }

    IpcHandler {
        target: "notifications"

        function dismiss(): void {
            root.popups[0]?.notification?.dismiss();
        }

        function dismissAll(): void {
            for (const entry of root.popups.slice())
                entry.notification?.dismiss();
        }
    }
}
