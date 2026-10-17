import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Entering power-saver saves the backlight level and dims to 30%, leaving a
// dimmer screen as it is; leaving power-saver restores the saved level. The
// level lives in a state file, so a bar restarted in power-saver neither dims
// again over a manual change nor forgets what to restore.
Scope {
    id: root

    // Quickshell reports Balanced until the daemon answers. The profile list,
    // in which TLP always offers performance, lands after the active profile,
    // so it marks the answer. The battery check comes first so that a host
    // without one never starts either service.
    readonly property bool ready: UPower.displayDevice.isLaptopBattery && Backlight.device !== "" && PowerProfiles.hasPerformanceProfile
    readonly property bool powerSaver: ready && PowerProfiles.profile === PowerProfile.PowerSaver

    function apply() {
        if (!ready)
            return;
        const stored = saved.text().trim();
        if (powerSaver && stored === "") {
            Backlight.read();
            saved.setText(String(Backlight.level));
            Backlight.set(Math.min(Backlight.level, Math.round(Backlight.max * 0.3)));
        } else if (!powerSaver && stored !== "") {
            Backlight.set(parseInt(stored));
            saved.setText("");
        }
    }

    onReadyChanged: Qt.callLater(apply)
    onPowerSaverChanged: Qt.callLater(apply)

    FileView {
        id: saved

        path: Quickshell.statePath("backlight")
        blockAllReads: true
        blockWrites: true
        printErrors: false
    }
}
