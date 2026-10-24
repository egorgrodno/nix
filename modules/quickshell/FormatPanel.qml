import QtQuick
import QtQuick.Controls.Basic
import Quickshell
import Quickshell.Io

// From the launcher: formats a USB drive, the whole of it or one partition in
// place, picked as FAT32, exFAT, NTFS or ext4 with a label. A full format
// writes zeros over it first. Format takes a second click. usb-format runs it
// out of the bar and reports how it ended as a notification, so the panel can
// close while it runs and shows its progress again when reopened.
Panel {
    id: panel

    readonly property var filesystems: [
        {
            type: "vfat",
            name: "FAT32",
            labelLength: 11,
            detail: "Read by nearly everything; no file over 4 GB"
        },
        {
            type: "exfat",
            name: "exFAT",
            labelLength: 15,
            detail: "Windows, macOS and Linux; no 4 GB file limit"
        },
        {
            type: "ntfs",
            name: "NTFS",
            labelLength: 32,
            detail: "Windows and Linux; macOS only reads it"
        },
        {
            type: "ext4",
            name: "ext4",
            labelLength: 16,
            detail: "Linux only, with owners and permissions"
        }
    ]
    // As usb-format lists them, every second.
    property var disks: []
    property bool listed: false
    property string selected: ""
    // The selected disk itself, or one of its partitions.
    property string target: ""
    property string fstype: "vfat"
    property bool full: false
    property bool armed: false
    // By disk, when a format started on it: the first listing after the start
    // can come before usb-format marks the disk busy.
    property var starting: ({})
    // By disk, the first progress seen of the job on it, as { path, time,
    // progress }, for the rate and the time left.
    property var samples: ({})
    readonly property var disk: disks.find(d => d.name === selected) ?? null
    readonly property bool busy: disk !== null && (disk.busy || disk.job !== null || disk.name in starting)
    readonly property bool form: disk !== null && !busy
    readonly property var filesystem: filesystems.find(f => f.type === fstype)

    function title(d) {
        return d.model !== "" ? d.model : "USB drive";
    }

    function select(name) {
        selected = name;
        if (disk)
            aim(name);
    }

    // The filesystem and label start as the device has them, a whole disk as
    // its only partition has them.
    function aim(device) {
        target = device;
        armed = false;
        const holding = device === disk.name ? (disk.partitions.length === 1 ? disk.partitions[0] : disk) : disk.partitions.find(p => p.name === device);
        fstype = filesystems.some(f => f.type === holding?.fstype) ? holding.fstype : "vfat";
        labelField.text = holding?.label ?? "";
    }

    function update(list) {
        const now = Date.now();
        const waiting = Object.assign({}, starting);
        for (const [name, time] of Object.entries(starting))
            if (now - time > 5000 || list.some(d => d.name === name && d.busy))
                delete waiting[name];
        starting = waiting;
        const seen = {};
        for (const d of list)
            if (d.job?.progress != null) {
                const sample = samples[d.name];
                seen[d.name] = sample?.path === d.job.path ? sample : {
                    path: d.job.path,
                    time: now,
                    progress: d.job.progress
                };
            }
        samples = seen;
        disks = list;
        listed = true;
        if (!disk)
            select(list[0]?.name ?? "");
        else if (target !== disk.name && !disk.partitions.some(p => p.name === target))
            aim(disk.name);
    }

    function start() {
        if (!armed) {
            armed = true;
            disarm.restart();
            return;
        }
        armed = false;
        Launcher.run([Programs.usbFormat, "format", target, fstype, labelField.text, full ? "full" : "quick"]);
        starting = Object.assign({}, starting, {
            [disk.name]: Date.now()
        });
    }

    function duration(seconds) {
        if (seconds < 60)
            return `${Math.max(1, Math.round(seconds))} s`;
        const minutes = Math.round(seconds / 60);
        return minutes < 60 ? `${minutes} min` : `${Math.floor(minutes / 60)} h ${minutes % 60} min`;
    }

    function progress(d) {
        const job = d.job;
        const phase = {
            "partition-create": "Partitioning",
            "format-erase": "Erasing",
            "format-mkfs": "Formatting"
        }[job?.operation] ?? "Formatting";
        if (job?.progress == null)
            return `${phase}…`;
        const parts = [phase, Stats.percent(job.progress * 100)];
        const sample = samples[d.name];
        const elapsed = (Date.now() - sample.time) / 1000;
        const done = job.progress - sample.progress;
        if (elapsed >= 3 && done > 0)
            parts.push(Stats.rate(done * job.bytes / elapsed), `${duration(elapsed * (1 - job.progress) / done)} left`);
        return parts.join(" · ");
    }

    upward: true
    boxWidth: 400

    Process {
        id: lister

        running: true
        command: [Programs.usbFormat, "list"]
        stdout: StdioCollector {
            onStreamFinished: if (text !== "")
                panel.update(JSON.parse(text))
        }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: lister.running = true
    }

    Timer {
        id: disarm

        interval: 3000
        onTriggered: panel.armed = false
    }

    Column {
        width: panel.contentWidth

        Repeater {
            model: ScriptModel {
                values: panel.disks
                objectProp: "name"
            }

            Item {
                id: row

                required property var modelData
                readonly property bool current: modelData.name === panel.selected

                width: panel.contentWidth
                height: 40

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.radius - 4
                    color: hover.hovered ? Theme.tint(0.07) : "transparent"

                    Behavior on color {
                        ColorAnimation {
                            duration: 150
                            easing.type: Easing.OutQuad
                        }
                    }
                }

                HoverHandler {
                    id: hover
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: if (!row.current)
                        panel.select(row.modelData.name)
                }

                BarText {
                    id: glyph

                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: "\u{F129E}"
                    color: row.current ? Theme.blue : Theme.foregroundStrong
                    font.pixelSize: 18
                }

                BarText {
                    anchors.left: glyph.right
                    anchors.leftMargin: 10
                    anchors.right: size.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    text: panel.title(row.modelData)
                    elide: Text.ElideRight
                    color: row.current ? Theme.blue : Theme.foregroundStrong
                }

                BarText {
                    id: size

                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: `${row.modelData.name} · ${Stats.decimal(row.modelData.size)}`
                    color: Theme.foregroundMuted
                    font.pixelSize: 14
                }
            }
        }

        Caption {
            visible: panel.listed && panel.disks.length === 0
            text: "Plug in a USB drive"
        }
    }

    Column {
        width: panel.contentWidth
        visible: panel.form
        spacing: 16

        Flow {
            width: parent.width
            visible: panel.disk?.partitions.length > 0
            spacing: 8

            Repeater {
                model: ScriptModel {
                    values: panel.disk ? [panel.disk.name, ...panel.disk.partitions.map(p => p.name)] : []
                }

                TextButton {
                    required property string modelData
                    readonly property var partition: panel.disk?.partitions.find(p => p.name === modelData) ?? null

                    text: partition ? `${modelData.replace("/dev/", "")} · ${Stats.decimal(partition.size)}` : "Whole drive"
                    lit: modelData === panel.target
                    hoverFill: lit ? Theme.blue : Theme.tint(0.12)
                    textColor: lit ? Theme.backgroundMain : Theme.foregroundStrong
                    onClicked: if (!lit)
                        panel.aim(modelData)
                }
            }
        }

        Column {
            width: parent.width
            spacing: 8

            Row {
                spacing: 8

                Repeater {
                    model: panel.filesystems

                    TextButton {
                        required property var modelData

                        text: modelData.name
                        lit: modelData.type === panel.fstype
                        hoverFill: lit ? Theme.blue : Theme.tint(0.12)
                        textColor: lit ? Theme.backgroundMain : Theme.foregroundStrong
                        onClicked: {
                            panel.fstype = modelData.type;
                            panel.armed = false;
                        }
                    }
                }
            }

            Caption {
                text: panel.filesystem.detail
            }
        }

        TextField {
            id: labelField

            width: parent.width
            height: 28
            leftPadding: 8
            rightPadding: 8
            topPadding: 0
            bottomPadding: 0
            verticalAlignment: TextInput.AlignVCenter
            maximumLength: panel.filesystem.labelLength
            placeholderText: "Label"
            placeholderTextColor: Theme.foregroundMuted
            color: Theme.foregroundStrong
            selectionColor: Theme.blue
            selectedTextColor: Theme.backgroundMain
            font.family: Theme.fontUI
            font.pixelSize: 14
            // As FAT stores it.
            font.capitalization: panel.fstype === "vfat" ? Font.AllUppercase : Font.MixedCase
            onTextEdited: panel.armed = false
            onAccepted: panel.start()

            background: Rectangle {
                radius: Theme.radius - 4
                color: Theme.tint(0.06)
                border.width: 1
                border.color: labelField.activeFocus ? Theme.blue : Theme.tint(0.12)
            }
        }

        Item {
            width: parent.width
            height: Math.max(fullTexts.implicitHeight, fullToggle.height)

            Column {
                id: fullTexts

                anchors.verticalCenter: parent.verticalCenter
                width: parent.width - fullToggle.width - 12
                spacing: 4

                BarText {
                    text: "Full format"
                }

                BarText {
                    width: parent.width
                    elide: Text.ElideRight
                    text: "Writes zeros over all of it first, which is slow"
                    color: Theme.foregroundMuted
                    font.pixelSize: 14
                }
            }

            Toggle {
                id: fullToggle

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: panel.full
                hovered: fullMouse.containsMouse
            }

            MouseArea {
                id: fullMouse

                anchors.fill: parent
                hoverEnabled: true
                onClicked: {
                    panel.full = !panel.full;
                    panel.armed = false;
                }
            }
        }

        Item {
            width: parent.width
            height: formatButton.height

            TextButton {
                id: formatButton

                anchors.right: parent.right
                text: {
                    if (!panel.armed || !panel.disk)
                        return "Format";
                    return panel.target === panel.disk.name ? `Erase all of ${panel.target}?` : `Erase ${panel.target}?`;
                }
                hoverFill: Theme.alpha(Theme.red, 0.5)
                lit: panel.armed
                onClicked: panel.start()
            }
        }
    }

    Column {
        width: panel.contentWidth
        visible: panel.busy
        spacing: 10

        Meter {
            width: parent.width
            visible: panel.disk?.job?.progress != null
            value: panel.disk?.job?.progress ?? 0
            graded: false
        }

        Item {
            width: parent.width
            height: cancelButton.height

            BarText {
                anchors.left: parent.left
                anchors.right: cancelButton.left
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: panel.disk ? panel.progress(panel.disk) : ""
                elide: Text.ElideRight
                font.pixelSize: 14
            }

            TextButton {
                id: cancelButton

                anchors.right: parent.right
                visible: panel.disk?.job != null
                text: "Cancel"
                onClicked: Quickshell.execDetached([Programs.usbFormat, "cancel", panel.disk.name])
            }
        }
    }
}
