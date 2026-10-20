import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Shown only where UPower reports a laptop battery, which also hides it where
// the UPower daemon does not run at all. Click opens the power panel.
Pill {
    id: battery

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property int capacity: Math.round(device.percentage * 100)
    // A battery held below full on AC is "Plugged".
    readonly property string status: {
        switch (device.state) {
        case UPowerDeviceState.Charging:
            return capacity === 100 ? "Full" : "Charging";
        case UPowerDeviceState.FullyCharged:
            return "Full";
        case UPowerDeviceState.Discharging:
            return UPower.onBattery ? "Discharging" : "Plugged";
        default:
            return capacity === 100 ? "Full" : UPower.onBattery ? "Discharging" : "Plugged";
        }
    }
    // UPower's own estimate can stay at zero for minutes after a plug event, so
    // the time comes from the battery's sysfs figures.
    readonly property string sysfs: {
        const laptop = UPower.devices.values.find(d => d.isLaptopBattery);
        return laptop ? `/sys/class/power_supply/${laptop.nativePath}` : "";
    }
    property real seconds: 0
    readonly property string time: {
        const hours = Math.floor(seconds / 3600);
        const minutes = Math.floor(seconds % 3600 / 60);
        return hours === 0 && minutes === 0 ? "" : `${hours} h ${minutes} min`;
    }
    // The tooltip, and the line under the power panel's charge.
    readonly property string summary: {
        switch (status) {
        case "Discharging":
            return time === "" ? "Discharging" : `Empty in ${time}`;
        case "Charging":
            return time === "" ? "Charging" : `Full in ${time}`;
        case "Plugged":
            return "Plugged in, not charging";
        default:
            return "Full";
        }
    }

    function sample() {
        energyNow.reload();
        energyFull.reload();
        powerNow.reload();
        const energy = parseInt(energyNow.text());
        const full = parseInt(energyFull.text());
        const power = parseInt(powerNow.text());
        seconds = !(power > 0) ? 0 : status === "Discharging" ? 3600 * energy / power : status === "Charging" ? 3600 * Math.max(0, full - energy) / power : 0;
        // The draw reads zero for some seconds after a plug event.
        if (seconds === 0 && (status === "Discharging" || status === "Charging"))
            retry.restart();
    }

    // The thresholds the firmware holds, whatever the state file says.
    readonly property int chargeStart: parseInt(limitStart.text())
    readonly property int chargeEnd: parseInt(limitEnd.text())

    function readLimits() {
        limitStart.reload();
        limitEnd.reload();
    }

    visible: device.isLaptopBattery
    lit: panel.active
    tooltip: summary
    onStatusChanged: sample()
    // Once the paths follow it.
    onSysfsChanged: Qt.callLater(sample)
    onClicked: button => {
        if (button === Qt.LeftButton) {
            if (panel.active)
                panel.item.close();
            else
                panel.active = true;
        }
    }

    Gauge {
        anchors.verticalCenter: parent.verticalCenter
        value: battery.capacity / 100
        fill: battery.status === "Charging" ? Theme.green : battery.capacity <= 10 ? Theme.red : battery.capacity <= 20 ? Theme.yellow : Theme.foregroundMain
        limit: battery.chargeEnd < 100 ? battery.chargeEnd / 100 : 1
    }

    BarText {
        anchors.verticalCenter: parent.verticalCenter
        visible: battery.status !== "Discharging"
        text: "\uF1E6"
        color: battery.status === "Charging" ? Theme.green : Theme.foregroundMuted
    }

    Figure {
        anchors.verticalCenter: parent.verticalCenter
        widest: "100%"
        text: `${battery.capacity}%`
    }

    FileView {
        id: energyNow

        path: battery.sysfs ? `${battery.sysfs}/energy_now` : ""
        blockAllReads: true
    }

    FileView {
        id: energyFull

        path: battery.sysfs ? `${battery.sysfs}/energy_full` : ""
        blockAllReads: true
    }

    FileView {
        id: powerNow

        path: battery.sysfs ? `${battery.sysfs}/power_now` : ""
        blockAllReads: true
    }

    FileView {
        id: limitStart

        path: battery.sysfs ? `${battery.sysfs}/charge_control_start_threshold` : ""
        blockAllReads: true
    }

    FileView {
        id: limitEnd

        path: battery.sysfs ? `${battery.sysfs}/charge_control_end_threshold` : ""
        blockAllReads: true
    }

    Timer {
        interval: 60000
        running: battery.visible
        repeat: true
        onTriggered: {
            battery.sample();
            battery.readLimits();
        }
    }

    Timer {
        id: retry

        interval: 5000
        onTriggered: battery.sample()
    }

    // Built on opening, so a host without a battery never starts the services
    // it reads.
    LazyLoader {
        id: panel

        PowerPanel {
            module: battery
            onDismissed: panel.active = false
        }
    }
}
