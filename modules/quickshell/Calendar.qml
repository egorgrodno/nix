import QtQuick

// The month as a grid from the locale's first weekday, today marked in blue.
Column {
    id: calendar

    required property date date
    readonly property var cells: {
        const locale = Qt.locale();
        const first = new Date(date.getFullYear(), date.getMonth(), 1);
        const days = new Date(date.getFullYear(), date.getMonth() + 1, 0).getDate();
        const cells = [];
        for (let i = 0; i < 7; i++)
            cells.push({
                text: locale.dayName((locale.firstDayOfWeek + i) % 7, Locale.ShortFormat).slice(0, 2),
                kind: "weekday"
            });
        for (let i = (first.getDay() - locale.firstDayOfWeek + 7) % 7; i > 0; i--)
            cells.push({
                text: "",
                kind: "blank"
            });
        for (let d = 1; d <= days; d++)
            cells.push({
                text: String(d),
                kind: d === date.getDate() ? "today" : "day"
            });
        return cells;
    }

    spacing: 8

    BarText {
        text: Qt.locale().toString(calendar.date, "MMMM yyyy")
    }

    Grid {
        columns: 7
        columnSpacing: 2
        rowSpacing: 2

        Repeater {
            model: calendar.cells

            Rectangle {
                id: cell

                required property var modelData

                width: 30
                height: 24
                radius: 4
                color: modelData.kind === "today" ? Theme.blue : "transparent"

                BarText {
                    anchors.centerIn: parent
                    text: cell.modelData.text
                    color: cell.modelData.kind === "weekday" ? Theme.foregroundMuted : cell.modelData.kind === "today" ? Theme.backgroundMain : "#ffffff"
                    font.family: cell.modelData.kind === "weekday" ? Theme.fontUI : Theme.fontMono
                    font.pixelSize: cell.modelData.kind === "weekday" ? 13 : 15
                }
            }
        }
    }
}
