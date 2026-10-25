import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io

// Over the clock: a month's days, opening on today's, with today selected. A
// click selects a day, and the arrow keys move the selection, the view
// following it into another month. The wheel, the ‹ › arrows, and Page Up and
// Page Down step the month, the days sliding sideways, and Home or Today goes
// back to today. A click on the title swaps in the year's months under a field
// for the year, which the same steps change, as typing a year and Enter does;
// a click on a month opens its days, as Escape goes back to the last ones. The
// month view takes the days' place, so the panel keeps its height. Below, the
// selected day in full; with Todoist, its tasks, which a drag moves onto
// another day and a click opens in a card in their place until another day is
// selected, and Quick Add for it; then the time in each of Nix's world clocks.
Panel {
    id: panel

    // The months over the days.
    property bool picking: false
    // ISO dates. The selection follows today until another day is selected.
    property string selected: today
    readonly property string today: Dates.of(clock.date)
    // Wider with Todoist, whose tasks the panel lists under the days.
    readonly property int cellWidth: Todoist.enabled ? 46 : 36
    readonly property int cellHeight: 28
    // Months since the start of year 0.
    readonly property int thisMonth: Dates.month(today)
    // Rows for the busiest day in the selected day's month, today's counting
    // what is overdue and its title, so the panel keeps its height from day to
    // day.
    readonly property int taskRows: {
        const month = Dates.month(selected);
        let rows = 1;
        for (const day in Todoist.byDay)
            if (Dates.month(day) === month)
                rows = Math.max(rows, Todoist.byDay[day].length);
        if (Dates.month(today) === month && Todoist.overdue.length > 0)
            rows = Math.max(rows, (Todoist.byDay[today]?.length ?? 0) + Todoist.overdue.length + 1);
        return rows;
    }

    function step(by) {
        if (picking)
            years.go(Math.max(1, Math.min(9999, years.page + by)));
        else
            months.go(Math.max(12, Math.min(9999 * 12 + 11, months.page + by)));
    }

    // A day, and its month into view.
    function select(day) {
        if (Dates.month(day) < 12 || Dates.month(day) > 9999 * 12 + 11)
            return;
        selected = day;
        months.go(Dates.month(day));
        calendar.forceActiveFocus();
    }

    function startPicking() {
        years.go(Math.floor(months.page / 12), false);
        field.text = years.page;
        picking = true;
        field.forceActiveFocus();
    }

    // To a month's days, or back to the last ones.
    function stopPicking(month = months.page) {
        months.go(month, false);
        picking = false;
        calendar.forceActiveFocus();
    }

    function goToday() {
        selected = today;
        if (picking)
            stopPicking(thisMonth);
        else
            months.go(thisMonth);
    }

    // The keys both views take, whichever holds the focus; false for any
    // other. In the month view the arrows step the year.
    function press(key) {
        switch (key) {
        case Qt.Key_Left:
        case Qt.Key_Right:
            if (picking)
                step(key === Qt.Key_Left ? -1 : 1);
            else
                select(Dates.add(selected, key === Qt.Key_Left ? -1 : 1));
            return true;
        case Qt.Key_Up:
        case Qt.Key_Down:
            if (picking)
                return false;
            select(Dates.add(selected, key === Qt.Key_Up ? -7 : 7));
            return true;
        case Qt.Key_PageUp:
            step(-1);
            return true;
        case Qt.Key_PageDown:
            step(1);
            return true;
        case Qt.Key_Home:
            goToday();
            return true;
        case Qt.Key_Escape:
            if (!picking)
                return false;
            stopPicking();
            return true;
        }
        return false;
    }

    // From today: "Today", "In 3 days", "2 days ago".
    function relative(day) {
        const n = Dates.between(today, day);
        switch (n) {
        case 0:
            return "Today";
        case 1:
            return "Tomorrow";
        case -1:
            return "Yesterday";
        }
        return n > 0 ? `In ${n} days` : `${-n} days ago`;
    }

    boxWidth: 7 * cellWidth + 6 * 2 + 2 * padding
    keyboardHome: calendar
    onSelectedChanged: list.reset()
    Component.onCompleted: {
        months.go(thisMonth, false);
        if (Todoist.enabled)
            Todoist.sync();
    }

    // A world clock: the zone's city, how far it runs ahead of here, and its
    // time. The offset comes from `date`, which knows the zone's rules, once
    // per opening.
    component Zone: Item {
        id: zone

        required property string modelData
        // Minutes east of UTC.
        property int offset: 0
        property bool known: false
        readonly property int ahead: offset + clock.date.getTimezoneOffset()

        width: panel.contentWidth
        height: 24

        BarText {
            anchors.verticalCenter: parent.verticalCenter
            text: zone.modelData.split("/").pop().replace(/_/g, " ")
            font.pixelSize: 14
        }

        Caption {
            anchors.right: time.left
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            visible: zone.known && zone.ahead !== 0
            text: {
                const minutes = Math.abs(zone.ahead);
                const rest = minutes % 60;
                return `${zone.ahead > 0 ? "+" : "−"}${Math.floor(minutes / 60)}${rest ? `:${Dates.pad(rest, 2)}` : ""} h`;
            }
        }

        Figure {
            id: time

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: zone.known ? Qt.locale("C").toString(new Date(clock.date.getTime() + zone.ahead * 60000), "HH:mm") : "--:--"
            font.pixelSize: 15
        }

        Process {
            running: true
            command: [Programs.date, "+%z"]
            environment: ({
                    TZ: zone.modelData
                })
            stdout: StdioCollector {
                onStreamFinished: {
                    const sign = text[0] === "-" ? -1 : 1;
                    zone.offset = sign * (Number(text.slice(1, 3)) * 60 + Number(text.slice(3, 5)));
                    zone.known = true;
                }
            }
        }
    }

    // A view that fades and scales as the other takes its place. Visible as
    // soon as it is shown, so the field in one can take the keyboard at once.
    component View: Item {
        property bool shown
        property real hiddenScale: 1

        opacity: shown ? 1 : 0
        scale: shown ? 1 : hiddenScale
        visible: shown || opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }

        Behavior on scale {
            NumberAnimation {
                duration: 200
                easing.type: Easing.OutQuad
            }
        }
    }

    Pager {
        id: months
    }

    Pager {
        id: years
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    // Takes the keyboard from the box, which still gets Escape from the days: a
    // key not taken here passes up to it. Over the panel's other items, so the
    // task dragged onto a day from the list below shows over the list too.
    Item {
        id: calendar

        z: 1
        width: panel.contentWidth
        height: header.height + 12 + pages.height
        Component.onCompleted: forceActiveFocus()
        Keys.onPressed: event => event.accepted = panel.press(event.key)

        // Under the rest, which passes the wheel on, and over the whole box.
        // Either wheel, as a touchpad scrolls sideways.
        MouseArea {
            property int wheel: 0

            anchors.fill: parent
            anchors.margins: -panel.padding
            acceptedButtons: Qt.NoButton
            onWheel: event => {
                wheel += event.angleDelta.x || event.angleDelta.y;
                const steps = Math.trunc(wheel / 120);
                if (steps !== 0) {
                    wheel -= steps * 120;
                    panel.step(-steps);
                }
            }
        }

        Item {
            id: header

            width: parent.width
            height: 32

            Chevron {
                anchors.verticalCenter: parent.verticalCenter
                by: -1
                onStepped: by => panel.step(by)
            }

            Chevron {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                by: 1
                onStepped: by => panel.step(by)
            }

            // Between the arrows, the month's name sliding with its days.
            View {
                id: titles

                x: 32
                width: parent.width - 64
                height: parent.height
                shown: !panel.picking
                clip: true

                Repeater {
                    model: 2

                    Item {
                        id: title

                        required property int index
                        readonly property int month: Math.floor(months.position) + index

                        x: (month - months.position) * titles.width
                        width: titles.width
                        height: titles.height

                        Rectangle {
                            id: titleFill

                            anchors.centerIn: parent
                            width: label.implicitWidth + 24
                            height: 28
                            radius: Theme.radius - 4
                            color: titleMouse.containsMouse ? Theme.tint(0.07) : "transparent"

                            Behavior on color {
                                ColorAnimation {
                                    duration: 150
                                    easing.type: Easing.OutQuad
                                }
                            }

                            MouseArea {
                                id: titleMouse

                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: panel.startPicking()
                            }
                        }

                        BarText {
                            id: label

                            anchors.centerIn: parent
                            text: `${Qt.locale().standaloneMonthName(title.month % 12)} ${Math.floor(title.month / 12)}`
                        }
                    }
                }
            }

            View {
                anchors.centerIn: parent
                width: 80
                height: 28
                shown: panel.picking

                TextField {
                    id: field

                    anchors.fill: parent
                    leftPadding: 8
                    rightPadding: 8
                    topPadding: 0
                    bottomPadding: 0
                    horizontalAlignment: TextInput.AlignHCenter
                    verticalAlignment: TextInput.AlignVCenter
                    maximumLength: 4
                    validator: IntValidator {
                        bottom: 1
                        top: 9999
                    }
                    color: Theme.foregroundStrong
                    selectionColor: Theme.blue
                    selectedTextColor: Theme.backgroundMain
                    font.family: Theme.fontMono
                    font.pixelSize: 15
                    onActiveFocusChanged: if (activeFocus)
                        selectAll()
                    // Before the field's own keys, so the arrows step the year
                    // rather than move the cursor.
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            if (acceptableInput)
                                years.go(parseInt(text));
                            text = years.page;
                            selectAll();
                            event.accepted = true;
                        } else
                            event.accepted = panel.press(event.key);
                    }

                    background: Rectangle {
                        radius: Theme.radius - 4
                        color: Theme.tint(0.06)
                        border.width: 1
                        border.color: field.activeFocus ? Theme.blue : Theme.tint(0.12)
                    }

                    Connections {
                        target: years

                        function onPageChanged() {
                            field.text = years.page;
                            if (field.activeFocus)
                                field.selectAll();
                        }
                    }
                }
            }
        }

        // Reaching into the box's padding on both sides, so the pages slide in
        // and out at its edges.
        Item {
            id: pages

            x: -panel.padding
            y: header.height + 12
            width: parent.width + 2 * panel.padding
            height: 7 * panel.cellHeight + 6 * 2
            clip: true

            View {
                anchors.fill: parent
                shown: !panel.picking
                hiddenScale: 0.92

                Repeater {
                    model: 2

                    CalendarMonth {
                        required property int index

                        month: Math.floor(months.position) + index
                        today: panel.today
                        selected: panel.selected
                        cellWidth: panel.cellWidth
                        cellHeight: panel.cellHeight
                        x: panel.padding + (month - months.position) * pages.width
                        onPicked: day => panel.select(day)
                    }
                }
            }

            View {
                anchors.fill: parent
                shown: panel.picking
                hiddenScale: 1.08

                Repeater {
                    model: 2

                    CalendarYear {
                        required property int index

                        year: Math.floor(years.position) + index
                        current: panel.thisMonth
                        shown: months.page
                        x: panel.padding + (year - years.position) * pages.width
                        width: panel.contentWidth
                        height: pages.height
                        onPicked: month => panel.stopPicking(month)
                    }
                }
            }
        }

        // The task a list row drags, where the pointer holds it.
        Rectangle {
            id: taskDrag

            property var task: null
            property bool dragging: false
            property point grab
            readonly property Item target: Drag.target

            visible: dragging
            opacity: 0.6
            height: 36
            radius: Theme.radius - 4
            color: Theme.alpha(Theme.backgroundRaised, 0.97)
            border.color: Theme.tint(0.12)
            border.width: 1
            Drag.active: dragging
            Drag.keys: ["task"]
            Drag.hotSpot: grab

            BarText {
                x: 36
                width: parent.width - x - 8
                anchors.verticalCenter: parent.verticalCenter
                elide: Text.ElideRight
                text: taskDrag.task?.content ?? ""
                font.pixelSize: 14
            }
        }
    }

    // The selected day in full, and Today while another day or month shows.
    Item {
        width: panel.contentWidth
        height: dayLines.implicitHeight

        Column {
            id: dayLines

            width: parent.width - (todayButton.visible ? todayButton.width + 12 : 0)
            spacing: 2

            BarText {
                width: parent.width
                elide: Text.ElideRight
                text: {
                    const [y, m, d] = panel.selected.split("-").map(Number);
                    const locale = Qt.locale();
                    return `${locale.dayName(Dates.weekday(panel.selected), Locale.LongFormat)}, ${d} ${locale.standaloneMonthName(m - 1)} ${y}`;
                }
                font.pixelSize: 15
            }

            Caption {
                text: `Week ${Dates.week(panel.selected)} · ${panel.relative(panel.selected)}`
            }
        }

        TextButton {
            id: todayButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: panel.selected !== panel.today || (panel.picking ? years.page !== Math.floor(panel.thisMonth / 12) : months.page !== panel.thisMonth)
            text: "Today"
            onClicked: panel.goToday()
        }
    }

    // Todoist's tasks due on the selected day, over those overdue on today,
    // without their projects, and Quick Add for the day. Escape in the field
    // gives the keyboard back to the days.
    Column {
        width: panel.contentWidth
        visible: Todoist.enabled
        spacing: 8

        TaskList {
            id: list

            width: parent.width
            minHeight: panel.taskRows * 36
            maxHeight: 6 * 36
            showProject: false
            dragProxy: taskDrag
            onClosed: calendar.forceActiveFocus()
            sections: panel.selected === panel.today ? [
                {
                    tasks: Todoist.byDay[panel.today] ?? []
                },
                {
                    title: "Overdue",
                    tasks: Todoist.overdue,
                    showDay: true,
                    action: Todoist.moveOverdue
                }
            ] : [
                {
                    tasks: Todoist.byDay[panel.selected] ?? []
                }
            ]

            Caption {
                height: 36
                visible: list.shown.length === 0 && list.trail.length === 0
                leftPadding: 8
                verticalAlignment: Text.AlignVCenter
                text: "Nothing due"
            }
        }

        TaskField {
            width: parent.width
            day: panel.selected
            Keys.onEscapePressed: calendar.forceActiveFocus()
        }

        TodoistStatus {}
    }

    Column {
        width: panel.contentWidth
        visible: Host.worldClocks.length > 0
        spacing: 4

        Repeater {
            model: Host.worldClocks

            Zone {}
        }
    }
}
