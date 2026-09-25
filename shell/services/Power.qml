pragma Singleton

// Power profile (tuned-ppd / power-profiles-daemon over D-Bus) and battery
// saver. Power-saver mode also turns off blur (DESIGN.md §6.2) — the single
// most expensive effect on the iGPU.
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property int profile: PowerProfiles.profile
    readonly property bool saver: profile === PowerProfile.PowerSaver
    readonly property string label: profile === PowerProfile.PowerSaver ? "Battery saver"
                                   : profile === PowerProfile.Performance ? "Performance" : "Balanced"
    readonly property string icon: profile === PowerProfile.PowerSaver ? "energy_savings_leaf"
                                  : profile === PowerProfile.Performance ? "bolt" : "balance"

    // Balanced → Performance → Saver → Balanced
    function cycle() {
        if (profile === PowerProfile.Balanced)
            PowerProfiles.profile = PowerProfiles.hasPerformanceProfile ? PowerProfile.Performance : PowerProfile.PowerSaver;
        else if (profile === PowerProfile.Performance) PowerProfiles.profile = PowerProfile.PowerSaver;
        else PowerProfiles.profile = PowerProfile.Balanced;
    }

    function applyBlur() {
        Hypr.set(`{ decoration = { blur = { enabled = ${saver ? "false" : "true"} } } }`);
    }
    onSaverChanged: applyBlur()
    Component.onCompleted: if (saver) applyBlur()
}
