import QtQuick
import Quickshell.Io
import Quickshell.Services.UPower

// Shown only where UPower reports a laptop battery, which also hides it where
// the UPower daemon does not run at all. Click swaps the charge for the time.
Pill {
    id: battery

    readonly property UPowerDevice device: UPower.displayDevice
    readonly property int capacity: Math.round(device.percentage * 100)
    // Waybar's status names. A battery held below full on AC is "Plugged".
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
    // the time comes from the battery's sysfs figures, as Waybar computed it.
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
    readonly property string icon: ["", "", "", "", ""][Math.min(Math.trunc(capacity / 20), 4)]
    property bool alt: false

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

    visible: device.isLaptopBattery
    hoverable: false
    text: status === "Charging" || status === "Plugged" ? ` ${capacity}%` : alt ? `${time} ${icon}` : `${icon} ${capacity}%`
    tooltip: time === "" ? status : `${status === "Discharging" ? "Empty" : "Full"} in ${time}`
    onClicked: button => {
        if (button === Qt.LeftButton)
            alt = !alt;
    }
    onStatusChanged: sample()
    // Once the paths follow it.
    onSysfsChanged: Qt.callLater(sample)

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

    // Waybar's interval.
    Timer {
        interval: 60000
        running: battery.visible
        repeat: true
        onTriggered: battery.sample()
    }

    Timer {
        id: retry

        interval: 5000
        onTriggered: battery.sample()
    }
}
