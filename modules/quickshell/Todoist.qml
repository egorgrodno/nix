pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Todoist through its API v1, with the token nx-setup keeps in the login
// keyring; without one the bar shows no Todoist at all. The active tasks and
// the projects come from the sync endpoint, incrementally after the first
// time, at start, every five minutes, as a panel opens and after every change,
// and persist in Quickshell's state directory, so a restart shows them at
// once. A change applies here at once and is undone should Todoist refuse it.
// A recurring task is moved by resending its whole due object with the new
// date, as any other edit to it would replace the recurrence.
Singleton {
    id: root

    readonly property string api: "https://api.todoist.com/api/v1"
    property string token: ""
    readonly property bool enabled: token !== ""
    // By id, the active tasks and the projects.
    property var items: ({})
    property var projects: ({})
    property string inbox: ""
    property string syncToken: "*"
    property bool syncing: false
    // Another sync was asked for while one ran.
    property bool again: false
    property string error: ""
    // The last change while it can be undone: { text, revert, commit }.
    property var lastChange: null
    // By id, the tasks deleted here whose delete waits for the Undo offer.
    property var deleting: ({})
    readonly property string today: Dates.of(clock.date)
    readonly property string now: Qt.locale("C").toString(clock.date, "HH:mm")
    readonly property var tasks: Object.values(items).filter(t => !deleting[t.id]).sort(compare)
    // ISO day to its tasks, in order.
    readonly property var byDay: {
        const days = {};
        for (const task of tasks) {
            const day = dayOf(task);
            if (day)
                (days[day] = days[day] ?? []).push(task);
        }
        return days;
    }
    readonly property var overdue: tasks.filter(t => {
        const day = dayOf(t);
        return day !== "" && day < today;
    })
    readonly property int dueCount: overdue.length + (byDay[today]?.length ?? 0)
    // The Overdue sections' action.
    readonly property var moveOverdue: ({
            label: "Move to today",
            run: () => rescheduleAll(overdue, today)
        })

    // The tasks module on the focused screen opens its panel, or closes it.
    signal toggleRequested

    // The local day a task is due, or "" for none: a date, a floating time, or
    // a UTC time in a fixed time zone.
    function dayOf(task) {
        const date = task.due?.date;
        if (!date)
            return "";
        return date.endsWith("Z") ? Dates.of(new Date(date)) : date.slice(0, 10);
    }

    // HH:mm, or "" for a task due on a day.
    function timeOf(task) {
        const date = task.due?.date ?? "";
        if (date.length <= 10)
            return "";
        return date.endsWith("Z") ? Qt.locale("C").toString(new Date(date), "HH:mm") : date.slice(11, 16);
    }

    // Whether a task's day has passed, or its time today.
    function late(task) {
        const day = dayOf(task);
        return day !== "" && (day < today || day === today && timeOf(task) !== "" && timeOf(task) < now);
    }

    // "Today", "Tomorrow" and "Yesterday", else "Sat 24 Oct", with the year
    // outside this one.
    function dayLabel(day) {
        switch (Dates.between(today, day)) {
        case 0:
            return "Today";
        case 1:
            return "Tomorrow";
        case -1:
            return "Yesterday";
        }
        const [y, m, d] = day.split("-").map(Number);
        const locale = Qt.locale();
        const label = `${locale.dayName(Dates.weekday(day), Locale.ShortFormat)} ${d} ${locale.standaloneMonthName(m - 1, Locale.ShortFormat)}`;
        return day.startsWith(today.slice(0, 4)) ? label : `${label} ${y}`;
    }

    function projectName(task) {
        return task.project_id === inbox ? "Inbox" : projects[task.project_id]?.name ?? "";
    }

    // By day, timed tasks first by time, then by priority, 4 being p1, then as
    // Todoist orders siblings.
    function compare(a, b) {
        const da = dayOf(a) || "~", db = dayOf(b) || "~";
        if (da !== db)
            return da < db ? -1 : 1;
        const ta = timeOf(a) || "~", tb = timeOf(b) || "~";
        if (ta !== tb)
            return ta < tb ? -1 : 1;
        return b.priority - a.priority || a.child_order - b.child_order;
    }

    function uuid() {
        return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, c => {
            const r = Math.random() * 16 | 0;
            return (c === "x" ? r : r & 3 | 8).toString(16);
        });
    }

    // Calls `done` with the parsed body of a 2xx, else sets `error` and calls
    // `failed`. A gateway's error comes as plain text.
    function request(path, body, done, failed) {
        const xhr = new XMLHttpRequest();
        xhr.open("POST", api + path);
        xhr.setRequestHeader("Authorization", `Bearer ${token}`);
        xhr.setRequestHeader("Content-Type", "application/json");
        xhr.onreadystatechange = () => {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            let data = null;
            try {
                data = JSON.parse(xhr.responseText);
            } catch (e) {}
            if (xhr.status >= 200 && xhr.status < 300) {
                error = "";
                done(data);
                return;
            }
            error = xhr.status === 0 ? "Todoist is unreachable" : xhr.status === 401 ? "Todoist rejected the token: run nx-setup" : `Todoist: ${data?.error ?? `HTTP ${xhr.status}`}`;
            failed?.();
        };
        xhr.send(JSON.stringify(body));
    }

    function sync() {
        if (!enabled) {
            readToken();
            return;
        }
        if (syncing) {
            again = true;
            return;
        }
        syncing = true;
        const finish = () => {
            syncing = false;
            if (again) {
                again = false;
                sync();
            }
        };
        request("/sync", {
            sync_token: syncToken,
            resource_types: ["items", "projects"]
        }, data => {
            apply(data);
            finish();
        }, finish);
    }

    function apply(data) {
        const items = data.full_sync ? {} : Object.assign({}, root.items);
        for (const task of data.items ?? []) {
            if (task.is_deleted || task.checked)
                delete items[task.id];
            else
                items[task.id] = task;
        }
        const projects = data.full_sync ? {} : Object.assign({}, root.projects);
        for (const project of data.projects ?? []) {
            if (project.is_deleted || project.is_archived)
                delete projects[project.id];
            else
                projects[project.id] = project;
            // Sync leaves the flag out unless it holds.
            if (project.inbox_project)
                inbox = project.id;
        }
        root.items = items;
        root.projects = projects;
        syncToken = data.sync_token;
        storage.setText(JSON.stringify({
            syncToken: syncToken,
            inbox: inbox,
            items: items,
            projects: projects
        }));
    }

    // Applies `items` here at once, then sends the commands, at most 100 to a
    // request as Todoist takes them. Should Todoist refuse any, the tasks go
    // back as they were and a full sync settles which commands took.
    function change(items, commands) {
        const before = root.items;
        root.items = items;
        const failed = () => {
            root.items = before;
            syncToken = "*";
            sync();
        };
        for (let i = 0; i < commands.length; i += 100)
            request("/sync", {
                commands: commands.slice(i, i + 100).map(c => Object.assign({
                        uuid: uuid()
                    }, c))
            }, data => {
                if (Object.values(data?.sync_status ?? {}).some(s => s !== "ok")) {
                    error = "Todoist refused the change";
                    failed();
                } else
                    sync();
            }, failed);
    }

    // Offers Undo for the last change, until the next or ten seconds pass,
    // then makes it final through `commit`, if any.
    function offerUndo(text, revert, commit) {
        settle();
        lastChange = {
            text: text,
            revert: revert,
            commit: commit
        };
        undoTimer.restart();
    }

    function settle() {
        const last = lastChange;
        lastChange = null;
        last?.commit?.();
    }

    function without(id) {
        const items = Object.assign({}, root.items);
        delete items[id];
        return items;
    }

    function withTask(task) {
        return Object.assign({}, items, {
            [task.id]: task
        });
    }

    // A recurring task leaves until the sync brings its next date.
    function complete(task) {
        change(without(task.id), [
            {
                type: "item_close",
                args: {
                    id: task.id
                }
            }
        ]);
        offerUndo(`Completed “${task.content}”`, () => change(withTask(task), [task.due?.is_recurring ? {
                    type: "item_update_date_complete",
                    args: {
                        id: task.id,
                        due: task.due,
                        is_forward: 0
                    }
                } : {
                    type: "item_uncomplete",
                    args: {
                        id: task.id
                    }
                }]));
    }

    function undo() {
        const last = lastChange;
        lastChange = null;
        last?.revert();
    }

    // With its subtasks, as Todoist deletes them. Todoist cannot restore a
    // deleted task, so the delete is sent only once the Undo offer ends, the
    // tasks hidden until then; a restart before that brings them back.
    function remove(task) {
        const ids = [task.id];
        for (const id of ids)
            ids.push(...Object.values(items).filter(t => t.parent_id === id).map(t => t.id));
        hide(ids, true);
        const subtasks = ids.length - 1;
        offerUndo(`Deleted “${task.content}”${subtasks === 0 ? "" : subtasks === 1 ? " and its subtask" : ` and ${subtasks} subtasks`}`, () => hide(ids, false), () => {
            const items = Object.assign({}, root.items);
            for (const id of ids)
                delete items[id];
            change(items, [
                {
                    type: "item_delete",
                    args: {
                        id: task.id
                    }
                }
            ]);
            hide(ids, false);
        });
    }

    function hide(ids, hidden) {
        const deleting = Object.assign({}, root.deleting);
        for (const id of ids) {
            if (hidden)
                deleting[id] = true;
            else
                delete deleting[id];
        }
        root.deleting = deleting;
    }

    // The due object a task takes on an ISO day, keeping its time of day and
    // any recurrence, or undefined for a time in a fixed zone, which only
    // `date` can move.
    function dueOn(task, day) {
        const old = task.due;
        if (!old)
            return {
                date: day
            };
        if (old.date.length <= 10)
            return moved(old, day);
        if (!old.date.endsWith("Z"))
            return moved(old, day + old.date.slice(10));
        return undefined;
    }

    // To an ISO day, or to none for "".
    function reschedule(task, day) {
        const due = day ? dueOn(task, day) : null;
        if (due === undefined)
            zoneShift.add(task, day);
        else
            update(task, due);
    }

    // Many tasks to one day at once, as overdue ones to today, with Undo
    // putting each back on its own due.
    function rescheduleAll(tasks, day) {
        const items = Object.assign({}, root.items);
        const commands = [];
        for (const task of tasks) {
            const due = dueOn(task, day);
            if (due === undefined) {
                zoneShift.add(task, day);
                continue;
            }
            items[task.id] = Object.assign({}, task, {
                due: due
            });
            commands.push({
                type: "item_update",
                args: {
                    id: task.id,
                    due: due
                }
            });
        }
        change(items, commands);
        offerUndo(`Moved ${tasks.length} ${tasks.length === 1 ? "task" : "tasks"} to ${dayLabel(day).toLowerCase()}`, () => {
            const back = Object.assign({}, root.items);
            for (const task of tasks)
                back[task.id] = task;
            change(back, tasks.map(task => ({
                        type: "item_update",
                        args: {
                            id: task.id,
                            due: task.due
                        }
                    })));
        });
    }

    // The due object with a new date: the whole of it for a recurring task, the
    // date and any time zone for another.
    function moved(due, date) {
        return due.is_recurring ? Object.assign({}, due, {
            date: date
        }) : due.timezone ? {
            date: date,
            timezone: due.timezone
        } : {
            date: date
        };
    }

    function update(task, due) {
        if ((task.due?.date ?? null) === (due?.date ?? null))
            return;
        change(withTask(Object.assign({}, task, {
            due: due
        })), [
            {
                type: "item_update",
                args: {
                    id: task.id,
                    due: due
                }
            }
        ]);
    }

    // Through Quick Add, which reads dates, #projects, @labels and p1 to p4
    // out of the text. A task it left without a date takes `day`, if any.
    function add(text, day) {
        request("/tasks/quick", {
            text: text
        }, task => {
            if (day && task?.id && !task.due)
                change(items, [
                    {
                        type: "item_update",
                        args: {
                            id: task.id,
                            due: {
                                date: day
                            }
                        }
                    }
                ]);
            else
                sync();
        });
    }

    function readToken() {
        if (!tokenReader.running)
            tokenReader.running = true;
    }

    Component.onCompleted: {
        try {
            const saved = JSON.parse(storage.text());
            items = saved.items ?? {};
            projects = saved.projects ?? {};
            inbox = saved.inbox ?? "";
            syncToken = saved.syncToken ?? "*";
        } catch (e) {}
        readToken();
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    FileView {
        id: storage

        path: Quickshell.statePath("todoist.json")
        blockAllReads: true
        printErrors: false
    }

    Process {
        id: tokenReader

        command: [Programs.secretTool, "lookup", "service", "todoist"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.token = text.trim();
                if (root.enabled)
                    root.sync();
            }
        }
    }

    Timer {
        interval: 5 * 60 * 1000
        running: root.enabled
        repeat: true
        onTriggered: root.sync()
    }

    Timer {
        id: undoTimer

        interval: 10000
        onTriggered: root.settle()
    }

    // A fixed time zone's task keeps its wall-clock time on the new day,
    // which only the zone's rules give: `date` reads the time there, then the
    // UTC instant of that time on the day. One at a time.
    Process {
        id: zoneShift

        property var queue: []
        property var current: null

        function add(task, day) {
            queue = [...queue, {
                    task: task,
                    day: day
                }];
            next();
        }

        function next() {
            if (running || queue.length === 0)
                return;
            current = queue[0];
            queue = queue.slice(1);
            const due = current.task.due;
            command = [Programs.sh, "-c", 'time=$(TZ="$1" "$4" -d "$2" +%T) && "$4" -u -d "TZ=\\"$1\\" $3 $time" +%Y-%m-%dT%H:%M:%SZ', "sh", due.timezone, due.date, current.day, Programs.date];
            running = true;
        }

        stdout: StdioCollector {
            onStreamFinished: {
                const date = text.trim();
                if (date)
                    root.update(zoneShift.current.task, root.moved(zoneShift.current.task.due, date));
            }
        }
        onExited: Qt.callLater(next)
    }

    IpcHandler {
        target: "todoist"

        function toggle(): void {
            if (root.enabled)
                root.toggleRequested();
        }

        function refresh(): void {
            root.sync();
        }
    }
}
