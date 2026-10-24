import QtQuick

// The disk tooltip: per drive its model, temperature and health, each mounted
// filesystem and five minutes of reads and writes, then the generations.
Column {
    id: tip

    // From the drive-health service's smartctl output, warnings in colour.
    function health(h) {
        if (!h)
            return [];
        const parts = [];
        if (h.passed === false)
            parts.push({
                text: "Failing",
                color: Theme.red
            });
        else if (h.critical)
            parts.push({
                text: "Critical warning",
                color: Theme.red
            });
        else if (h.passed)
            parts.push("Healthy");
        if (h.spare < h.spareThreshold)
            parts.push({
                text: `${h.spare}% spare`,
                color: Theme.red
            });
        if (!isNaN(h.worn))
            parts.push({
                text: `${h.worn}% worn`,
                color: h.worn >= 90 ? Theme.red : h.worn >= 70 ? Theme.yellow : Theme.foregroundMuted
            });
        if (!isNaN(h.written))
            parts.push(`${Stats.decimal(h.written)} written`);
        for (const [count, what] of [[h.mediaErrors, "media errors"], [h.reallocated, "reallocated sectors"], [h.pending, "pending sectors"]])
            if (count > 0)
                parts.push({
                    text: `${count} ${what}`,
                    color: Theme.yellow
                });
        if (!isNaN(h.hours))
            parts.push(`${Number(h.hours).toLocaleString(Qt.locale(), "f", 0)} h powered on`);
        return parts;
    }

    spacing: 16

    Poll {
        onPoll: {
            Stats.sampleDrives();
            Stats.sampleIo(false);
            Stats.sampleGenerations();
        }
    }

    Repeater {
        model: Stats.drives

        Column {
            id: drive

            required property var modelData
            readonly property var io: Stats.io[modelData.name] ?? null
            // Alignment leaves a drive's edges unpartitioned, so the two are
            // compared as shown.
            readonly property string capacity: {
                const [mounted, size] = [modelData.mounted, modelData.size].map(Stats.decimal);
                return mounted === size ? size : `${mounted} of ${size}`;
            }

            spacing: 8

            Column {
                spacing: 2

                Facts {
                    size: 16
                    color: Theme.foregroundStrong
                    parts: [drive.modelData.model, drive.capacity, isNaN(drive.modelData.temp) ? "" : {
                            text: Math.round(drive.modelData.temp),
                            widest: "00",
                            suffix: " °C",
                            color: Stats.tempColor(drive.modelData.temp, drive.modelData.health?.tempWarn || 70, drive.modelData.health?.tempCrit || 80, Theme.foregroundStrong)
                        }]
                }

                Facts {
                    parts: tip.health(drive.modelData.health)
                }
            }

            Repeater {
                model: drive.modelData.filesystems

                UsageRow {
                    required property var modelData

                    label: modelData.mount
                    value: modelData.used / modelData.size
                    amount: Stats.size(modelData.avail)
                    detail: `free · ${modelData.type}`
                }
            }

            Row {
                visible: drive.io !== null
                spacing: 16

                Repeater {
                    model: [["Read", "read"], ["Write", "write"]]

                    Row {
                        required property var modelData

                        spacing: 6

                        Caption {
                            anchors.verticalCenter: parent.verticalCenter
                            text: parent.modelData[0]
                        }

                        Spark {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 60
                            height: 18
                            floor: 1e6
                            values: drive.io?.[`${parent.modelData[1]}History`] ?? []
                        }

                        Figure {
                            anchors.verticalCenter: parent.verticalCenter
                            widest: "000 Kb/s"
                            horizontalAlignment: Text.AlignRight
                            text: Stats.rate(drive.io?.[parent.modelData[1]] ?? 0)
                            font.pixelSize: 14
                        }
                    }
                }
            }
        }
    }

    Facts {
        parts: Stats.generations.length > 0 ? [`${Stats.generations.length} generations`, `oldest ${Qt.formatDate(Stats.generations[0].time, "d MMM yyyy")}`] : []
    }
}
