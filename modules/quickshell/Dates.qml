pragma Singleton

import QtQuick
import Quickshell

// Arithmetic on days, each an ISO date string such as Todoist's due dates, and
// on months counted from the start of year 0. Worked in UTC, so no daylight
// saving shift moves a day, and through setUTCFullYear, valid for any year:
// Date reads 0 to 99 as 1900 to 1999.
Singleton {
    function pad(n, width) {
        return String(n).padStart(width, "0");
    }

    function utc(year, monthIndex, day) {
        const t = new Date(0);
        t.setUTCFullYear(year, monthIndex, day);
        return t;
    }

    function fromUtc(t) {
        return `${pad(t.getUTCFullYear(), 4)}-${pad(t.getUTCMonth() + 1, 2)}-${pad(t.getUTCDate(), 2)}`;
    }

    function parse(day) {
        const [y, m, d] = day.split("-").map(Number);
        return utc(y, m - 1, d);
    }

    // The local day of a Date.
    function of(date) {
        return `${pad(date.getFullYear(), 4)}-${pad(date.getMonth() + 1, 2)}-${pad(date.getDate(), 2)}`;
    }

    // Day `n` of a month, overflowing into the months either side.
    function day(month, n) {
        return fromUtc(utc(Math.floor(month / 12), month % 12, n));
    }

    function month(day) {
        const [y, m] = day.split("-").map(Number);
        return y * 12 + m - 1;
    }

    function length(month) {
        return utc(Math.floor(month / 12), month % 12 + 1, 0).getUTCDate();
    }

    // 0 is Sunday, as Date counts.
    function weekday(day) {
        return parse(day).getUTCDay();
    }

    function add(day, n) {
        const t = parse(day);
        t.setUTCDate(t.getUTCDate() + n);
        return fromUtc(t);
    }

    function between(from, to) {
        return Math.round((parse(to) - parse(from)) / 86400000);
    }

    // ISO 8601: weeks start on Monday, and week 1 holds the year's first
    // Thursday, so a day's week is its Thursday's.
    function week(day) {
        const t = parse(day);
        t.setUTCDate(t.getUTCDate() + 3 - (t.getUTCDay() + 6) % 7);
        return 1 + Math.floor((t - utc(t.getUTCFullYear(), 0, 1)) / 604800000);
    }
}
