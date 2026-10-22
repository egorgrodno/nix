import QtQuick
import Quickshell

// The time centred over the date. A click opens the calendar; a right-click
// swaps in seconds and the numeric date.
Pill {
    id: clock

    property bool alt: false
    // As wide as the widest date, so the module keeps its width day to day.
    readonly property real dateWidth: {
        const c = Qt.locale("C");
        const widest = (count, text) => Math.max(...Array.from({
                    length: count
                }, (_, i) => metrics.advanceWidth(text(i))));
        return widest(7, i => `${c.dayName(i, Locale.ShortFormat)}, `) + widest(31, i => String(i + 1)) + widest(12, i => ` ${c.monthName(i, Locale.ShortFormat)}`);
    }

    lit: panel.active
    onClicked: button => {
        if (button === Qt.LeftButton) {
            if (panel.active)
                panel.item.close();
            else
                panel.active = true;
        } else if (button === Qt.RightButton)
            alt = !alt;
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter

        Figure {
            anchors.horizontalCenter: parent.horizontalCenter
            text: Qt.locale("C").toString(time.date, clock.alt ? "HH:mm:ss" : "HH:mm")
            font.pixelSize: 17
        }

        Caption {
            id: dateLine

            width: Math.max(implicitWidth, clock.dateWidth)
            horizontalAlignment: Text.AlignHCenter
            // strftime's %e: the day of the month, space-padded.
            text: {
                const c = Qt.locale("C");
                return clock.alt ? `${String(time.date.getDate()).padStart(2)}.${c.toString(time.date, "MM.yyyy")}` : c.toString(time.date, "ddd, d MMM");
            }
            font.pixelSize: 12
        }
    }

    FontMetrics {
        id: metrics

        font: dateLine.font
    }

    SystemClock {
        id: time

        precision: SystemClock.Seconds
    }

    LazyLoader {
        id: panel

        CalendarPanel {
            module: clock
            onDismissed: panel.active = false
        }
    }
}
