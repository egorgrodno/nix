pragma Singleton

import QtQuick
import Quickshell

// What Todoist's Quick Add reads out of a task's text, as spans to mark: p1 to
// p4 or !!1 to !!4, the first counting; #project and a /section of it, the
// last counting, and @labels, each only once it exists, a space in its name
// escaped as `\ `; and the last date anywhere, a day and a time next to each
// other reading as one. Todoist has no endpoint that parses without adding, so
// the rules are what its parser did with sample text, and the dates only forms
// it was seen to read.
Singleton {
    id: root

    readonly property string weekday: "monday|mon|tuesday|tues|tue|wednesday|wed|thursday|thurs|thur|thu|friday|fri|saturday|sat|sunday|sun"
    // Alone, a month's full name reads as its first day, a short one as nothing.
    readonly property string fullMonth: "january|february|march|april|may|june|july|august|september|october|november|december"
    readonly property string month: `${fullMonth}|jan|feb|mar|apr|jun|jul|aug|sept|sep|oct|nov|dec`
    readonly property string dayOfMonth: "\\d{1,2}(?:st|nd|rd|th)?"
    readonly property string day: ["day after tomorrow", "today|tod|tonight|tomorrow|tmrw|tom|yesterday", "next (?:week|month|year)|this weekend|end of month", `(?:next |this )?(?:${weekday})`, "in \\d+ (?:minutes?|mins?|hours?|days?|weeks?|months?|years?)", `every (?:other )?(?:\\d+ )?(?:days?|weeks?|months?|years?|weekday|workday|morning|(?:${weekday})(?:,? (?:${weekday}))*)`, `(?:${month}) ${dayOfMonth}(?: \\d{4})?`, `${dayOfMonth} (?:${month})(?: \\d{4})?`, `mid (?:${fullMonth})`, fullMonth, "(?:on the )?\\d{1,2}(?:st|nd|rd|th)", "\\d{1,2}/\\d{1,2}(?:/\\d{2,4})?", "\\d{4}-\\d{2}-\\d{2}"].join("|")
    readonly property string time: "(?:at )?(?:\\d{1,2}(?::\\d{2})? ?[ap]m|\\d{1,2}:\\d{2}|noon|midnight)|at \\d{1,2}|morning|evening|night"
    // A day or a time standing apart, a comma or full stop after it allowed.
    readonly property var part: new RegExp(`(^|\\s)(?:(${day})|(${time}))(?=[,.]?(?:\\s|$))`, "gi")

    function named(objects, name) {
        return Object.values(objects).filter(o => o.name.toLowerCase() === name);
    }

    // [{ start, end, kind }], kind one of priority, project, section, label
    // and date, a priority's mark also carrying it as Todoist numbers it.
    function tokens(text) {
        const marks = [];
        const slashes = [];
        let priority = null;
        let project = null;
        const words = /(?:\\ |\S)+/g;
        for (let m; (m = words.exec(text)) !== null;) {
            const word = m[0];
            const span = {
                start: m.index,
                end: m.index + word.length
            };
            const name = word.slice(1).replace(/\\ /g, " ").toLowerCase();
            const found = word[0] === "#" ? named(Todoist.projects, name)[0] : undefined;
            if (/^(?:p|!!)[1-4]$/i.test(word))
                priority = priority ?? Object.assign(span, {
                    kind: "priority",
                    priority: 5 - Number(word.slice(-1))
                });
            else if (found)
                project = Object.assign(span, {
                    kind: "project",
                    id: found.id
                });
            else if (word[0] === "/")
                slashes.push(Object.assign(span, {
                    kind: "section",
                    name: name
                }));
            else if (word[0] === "@" && named(Todoist.labels, name).length > 0)
                marks.push(Object.assign(span, {
                    kind: "label"
                }));
        }
        const projectId = project?.id ?? Todoist.inbox;
        const section = slashes.reverse().find(s => named(Todoist.sections, s.name).some(t => t.project_id === projectId));
        marks.push(...[priority, project, section].filter(t => t));

        // Days and times next to each other join, as long as neither repeats.
        const phrases = [];
        part.lastIndex = 0;
        for (let m; (m = part.exec(text)) !== null;) {
            const start = m.index + m[1].length;
            const end = m.index + m[0].length;
            const kind = m[2] !== undefined ? "day" : "time";
            if (marks.some(t => start < t.end && t.start < end))
                continue;
            const last = phrases[phrases.length - 1];
            if (last && !last[kind] && /^\s+$/.test(text.slice(last.end, start))) {
                last.end = end;
                last[kind] = true;
            } else
                phrases.push({
                    start: start,
                    end: end,
                    kind: "date",
                    [kind]: true
                });
        }
        if (phrases.length > 0)
            marks.push(phrases[phrases.length - 1]);
        return marks;
    }
}
