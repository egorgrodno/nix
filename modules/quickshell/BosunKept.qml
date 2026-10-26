pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// Where the bosun panel was when it closed, so it opens there again: the
// selection, the size, the Log's filters, scroll positions and drafts.
// LazyLoader destroys the panel on close, so this keeps them, in a file whose
// place CLAUDE.md explains. A press that armed a button is never kept.
Singleton {
    id: root

    // The selected row's key, as BosunSidebar names them, or "spawn".
    property string selected: ""
    // What the New worker form returns to.
    property string beforeSpawn: ""
    // What the selected row showed when last seen: a decision, a session or a
    // Log entry, which the panel shows once its row is gone.
    property var held: null
    // The Log entry last selected, which the Log opens on.
    property var logEntry: null
    property bool expanded: false
    // While the expanded panel shows the whole sidebar beside the rail.
    property bool sidebarShown: false
    // The expanded Log's filters: "all", "decisions", "messages", "sessions"
    // or "yours"; a session or ""; and text.
    property string logKind: "all"
    property string logSession: ""
    property string logText: ""
    // By key, such as "deny:<id>" or "spawn", anything JSON holds.
    property var drafts: ({})
    // By key, such as "sidebar" or a selection's key, anything JSON holds.
    property var scrolls: ({})

    function draft(key) {
        return drafts[key] ?? "";
    }

    // "" or null forgets it.
    function keepDraft(key, value) {
        if ((value ?? "") === "" && !(key in drafts))
            return;
        const next = Object.assign({}, drafts);
        if ((value ?? "") === "")
            delete next[key];
        else
            next[key] = value;
        drafts = next;
    }

    function scroll(key) {
        return scrolls[key];
    }

    function keepScroll(key, value) {
        if (JSON.stringify(scrolls[key]) === JSON.stringify(value))
            return;
        scrolls = Object.assign({}, scrolls, {
            [key]: value
        });
    }

    // What `key` names while its row is there.
    function liveItem(key) {
        const at = key.indexOf(":");
        const id = key.slice(at + 1);
        switch (at < 0 ? key : key.slice(0, at)) {
        case "decision":
            return Bosun.decisions.find(d => d.id === id) ?? null;
        case "session":
            return Bosun.sessions.find(s => s.node === id) ?? null;
        case "log":
            return Bosun.log.find(e => `${e.seq}` === id) ?? null;
        }
        return null;
    }

    // `item` stands in for the key's row when it has none: a settled
    // decision or a Log entry, as the Log holds them.
    function select(key, item) {
        if (key === selected)
            return;
        held = liveItem(key) ?? item ?? null;
        if (key.startsWith("log:") && held)
            logEntry = held;
        selected = key;
    }

    function refresh() {
        const live = liveItem(selected);
        if (live)
            held = live;
    }

    function save() {
        if (file.path === "")
            return;
        const text = JSON.stringify({
            selected: selected,
            beforeSpawn: beforeSpawn,
            held: held,
            logEntry: logEntry,
            expanded: expanded,
            sidebarShown: sidebarShown,
            logKind: logKind,
            logSession: logSession,
            logText: logText,
            drafts: drafts,
            scrolls: scrolls
        });
        if (text !== saving.written) {
            file.setText(text);
            saving.written = text;
        }
    }

    onSelectedChanged: saving.restart()
    onBeforeSpawnChanged: saving.restart()
    onHeldChanged: saving.restart()
    onLogEntryChanged: saving.restart()
    onExpandedChanged: saving.restart()
    onSidebarShownChanged: saving.restart()
    onLogKindChanged: saving.restart()
    onLogSessionChanged: saving.restart()
    onLogTextChanged: saving.restart()
    onDraftsChanged: saving.restart()
    onScrollsChanged: saving.restart()

    Component.onCompleted: {
        let kept = {};
        try {
            kept = JSON.parse(file.text());
        } catch (e) {}
        selected = kept.selected ?? "";
        beforeSpawn = kept.beforeSpawn ?? "";
        held = kept.held ?? null;
        logEntry = kept.logEntry ?? null;
        expanded = kept.expanded === true;
        sidebarShown = kept.sidebarShown === true;
        logKind = kept.logKind ?? "all";
        logSession = kept.logSession ?? "";
        logText = kept.logText ?? "";
        drafts = kept.drafts ?? {};
        scrolls = kept.scrolls ?? {};
        refresh();
    }

    // The selected row's latest, while it is there.
    Connections {
        target: Bosun

        function onDecisionsChanged() {
            root.refresh();
        }

        function onSessionsChanged() {
            root.refresh();
        }

        function onLogChanged() {
            root.refresh();
        }
    }

    FileView {
        id: file

        readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") ?? ""
        readonly property string instance: Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") ?? ""

        path: dir && instance ? `${dir}/bosun-panel-${instance}.json` : ""
        blockAllReads: true
        printErrors: false
    }

    // A keystroke or a scroll changes it many times a second.
    Timer {
        id: saving

        property string written: ""

        interval: 500
        onTriggered: root.save()
    }
}
