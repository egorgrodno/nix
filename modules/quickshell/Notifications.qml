pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification daemon and its history. Each notification gets an entry
// that copies its data, so the entry outlives it: in the panel once its popup
// ends, across restarts in a state file, and on screen as a card leaves. The
// server expires nothing itself: each popup runs its own timer, and a
// notification stays with its sender until dismissed, invoked or withdrawn.
Singleton {
    id: root

    // Newest first, at most 100.
    property list<Entry> entries: []
    // At most five.
    readonly property list<Entry> popups: entries.filter(e => e.popup)
    // Only critical notifications pop up meanwhile.
    property bool dnd: false
    // When the panel last opened or closed, in ms since the epoch.
    property real seenAt: 0
    readonly property var unseen: entries.filter(e => e.time > seenAt)
    // While it is open, new notifications land in it rather than popping up.
    property bool panelOpen: false
    // Open panels, registered by Panel.qml: one on the popups' screen holds
    // their timers, since it covers them.
    property var panels: []
    readonly property ShellScreen screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? null
    readonly property bool held: panels.some(p => p.screen === root.screen)
    // As idle inhibition counts it; only critical notifications pop up over it.
    readonly property bool fullscreen: Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen ?? false

    // The bell on the focused screen opens or closes its panel.
    signal toggleRequested

    // dunst's replacement hints, which the scripts send.
    function tagOf(notification) {
        const hints = notification.hints;
        return String(hints["x-dunst-stack-tag"] ?? hints["synchronous"] ?? hints["x-canonical-private-synchronous"] ?? "");
    }

    // As the panel shows it.
    function ageOf(time) {
        const minutes = Math.floor((clock.date.getTime() - time) / 60000);
        if (minutes < 1)
            return "now";
        if (minutes < 60)
            return `${minutes}m`;
        const hours = Math.floor(minutes / 60);
        return hours < 24 ? `${hours}h` : `${Math.floor(hours / 24)}d`;
    }

    function remove(entry) {
        entries = entries.filter(e => e !== entry);
        if (entry.imageFile !== "")
            Quickshell.execDetached([Programs.rm, "-f", entry.imageFile]);
        // Once the card has left, which reads it until then.
        entry.destroy(1000);
        save();
    }

    function clear() {
        for (const entry of entries.slice())
            entry.dismiss();
    }

    function panelOpened() {
        panelOpen = true;
        seenAt = Date.now();
        for (const entry of popups.slice())
            entry.endPopup();
    }

    function panelClosed() {
        panelOpen = false;
        seenAt = Date.now();
    }

    function save() {
        saveTimer.restart();
    }

    onDndChanged: save()
    onSeenAtChanged: save()
    // Popups already up leave for the panel, as those arriving meanwhile go.
    onFullscreenChanged: {
        if (!fullscreen)
            return;
        for (const entry of popups.slice())
            if (entry.urgency !== NotificationUrgency.Critical)
                entry.endPopup();
    }

    component Entry: QtObject {
        id: entry

        // Null once it closes, and for an entry restored from the state file.
        property Notification notification
        property bool popup
        property real time: Date.now()
        property string appName
        property string appIcon
        property string desktopEntry
        property string summary
        property string body
        // As the sender gave it. An `image-data` image's URL dies with the
        // notification, so a card that shows one saves it to `imageFile`.
        property string imageSource
        property string imageFile
        readonly property string image: imageFile !== "" ? `file://${imageFile}` : imageSource
        property int urgency: NotificationUrgency.Normal
        // A `value` hint from 0 to 100, or -1.
        property int value: -1
        property string tag
        property bool isTransient
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
            desktopEntry = n.desktopEntry;
            summary = n.summary;
            body = n.body;
            if (n.image !== imageSource) {
                imageSource = n.image;
                if (imageFile !== "")
                    Quickshell.execDetached([Programs.rm, "-f", imageFile]);
                imageFile = "";
            }
            urgency = n.urgency;
            value = n.hints.value === undefined ? -1 : Number(n.hints.value);
            tag = root.tagOf(n);
            isTransient = n.transient;
            expireTimeout = n.expireTimeout;
            if (timer.running)
                timer.restart();
            root.save();
        }

        // Into the panel, or gone for a transient one, which keeps no history.
        function endPopup() {
            if (isTransient)
                notification?.expire();
            else
                popup = false;
        }

        function dismiss() {
            if (notification)
                notification.dismiss();
            else
                root.remove(entry);
        }

        // To make room, as the oldest of 100.
        function drop() {
            if (notification)
                notification.expire();
            else
                root.remove(entry);
        }

        function saved() {
            return {
                time: time,
                appName: appName,
                appIcon: appIcon,
                desktopEntry: desktopEntry,
                summary: summary,
                body: body,
                imageSource: imageSource.startsWith("image://qsimage/") ? "" : imageSource,
                imageFile: imageFile,
                urgency: urgency,
                value: value
            };
        }

        Component.onCompleted: if (notification)
            refresh()

        readonly property Timer timer: Timer {
            interval: entry.timeout
            running: entry.popup && entry.timeout > 0 && !entry.hovered && !root.held
            onTriggered: entry.endPopup()
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
            const pops = !root.panelOpen && (notification.urgency === NotificationUrgency.Critical || !root.dnd && !root.fullscreen);
            const tag = root.tagOf(notification);
            const same = tag === "" ? null : root.entries.find(e => e.tag === tag);
            if (same) {
                // Switched before the old one closes, so its close does not
                // remove the entry. A popup keeps its place; an entry in the
                // panel comes back to the top.
                const old = same.notification;
                same.notification = notification;
                same.time = Date.now();
                same.refresh();
                old?.expire();
                if (!same.popup) {
                    same.popup = pops;
                    root.entries = [same, ...root.entries.filter(e => e !== same)];
                }
                return;
            }
            if (!pops && notification.transient) {
                notification.expire();
                return;
            }
            root.entries = [entryComponent.createObject(root, {
                    notification: notification,
                    popup: pops
                }), ...root.entries];
            if (root.popups.length > 5)
                root.popups[5].endPopup();
            for (const entry of root.entries.slice(100))
                entry.drop();
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // Transient entries keep no history.
    Timer {
        id: saveTimer

        interval: 1000
        onTriggered: storage.setText(JSON.stringify({
            dnd: root.dnd,
            seenAt: root.seenAt,
            entries: root.entries.filter(e => !e.isTransient).map(e => e.saved())
        }))
    }

    // Also creates the directory the images go in.
    FileView {
        id: storage

        path: Quickshell.statePath("notifications/history.json")
        blockAllReads: true
        printErrors: false
    }

    Component.onCompleted: {
        let state = {};
        try {
            state = JSON.parse(storage.text());
        } catch (e) {
            save();
        }
        dnd = state.dnd ?? false;
        seenAt = state.seenAt ?? 0;
        entries = [...entries, ...(state.entries ?? []).map(s => entryComponent.createObject(root, s))];
    }

    IpcHandler {
        target: "notifications"

        function dismiss(): void {
            root.popups[0]?.dismiss();
        }

        function dismissAll(): void {
            for (const entry of root.popups.slice())
                entry.dismiss();
        }

        function toggle(): void {
            root.toggleRequested();
        }

        function clear(): void {
            root.clear();
        }

        function dnd(): void {
            root.dnd = !root.dnd;
        }
    }
}
