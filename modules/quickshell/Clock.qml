import QtQuick
import Quickshell

// Click swaps in the date with seconds. The tooltip is Waybar's month calendar
// text, so its columns are as ragged in the proportional font as Waybar's.
Pill {
    id: clock

    property bool alt: false

    // strftime's %e: the day of the month, space-padded.
    function day(date) {
        return String(date.getDate()).padStart(2);
    }

    function calendar(date) {
        const locale = Qt.locale();
        const first = new Date(date.getFullYear(), date.getMonth(), 1);
        const days = new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
        const firstWeekday = locale.firstDayOfWeek;

        const names = [];
        for (let i = 0; i < 7; i++)
            names.push(locale.dayName((firstWeekday + i) % 7, Locale.ShortFormat).slice(0, 2).padStart(2));

        const lines = [locale.toString(date, "MMMM yyyy"), names.join(" ")];
        let week = Array((first.getDay() - firstWeekday + 7) % 7).fill("  ");
        for (let d = 1; d <= days; d++) {
            week.push(String(d).padStart(2));
            if (week.length === 7 || d === days) {
                lines.push(week.join(" "));
                week = [];
            }
        }
        return lines.join("\n");
    }

    text: {
        const c = Qt.locale("C");
        return alt ? `${day(time.date)}.${c.toString(time.date, "MM.yyyy HH:mm:ss")}` : c.toString(time.date, "ddd MMM dd yyyy HH:mm");
    }
    tooltip: calendar(time.date)
    onClicked: button => {
        if (button === Qt.LeftButton)
            alt = !alt;
    }

    SystemClock {
        id: time

        precision: SystemClock.Seconds
    }
}
