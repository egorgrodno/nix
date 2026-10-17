import QtQuick
import Quickshell

// The time over the date. Click swaps in seconds and the numeric date.
Pill {
    id: clock

    property bool alt: false

    tooltipContent: Component {
        Calendar {
            date: time.date
        }
    }
    onClicked: button => {
        if (button === Qt.LeftButton)
            alt = !alt;
    }

    Column {
        anchors.verticalCenter: parent.verticalCenter

        Figure {
            anchors.right: parent.right
            text: Qt.locale("C").toString(time.date, clock.alt ? "HH:mm:ss" : "HH:mm")
            font.pixelSize: 17
        }

        Caption {
            anchors.right: parent.right
            // strftime's %e: the day of the month, space-padded.
            text: {
                const c = Qt.locale("C");
                return clock.alt ? `${String(time.date.getDate()).padStart(2)}.${c.toString(time.date, "MM.yyyy")}` : c.toString(time.date, "ddd MMM dd yyyy");
            }
            font.pixelSize: 12
        }
    }

    SystemClock {
        id: time

        precision: SystemClock.Seconds
    }
}
