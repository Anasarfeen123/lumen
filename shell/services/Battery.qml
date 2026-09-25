pragma Singleton

// Laptop battery via UPower (event-driven over D-Bus).
import QtQuick
import Quickshell
import Quickshell.Services.UPower

Singleton {
    id: root

    readonly property var device: UPower.displayDevice
    readonly property bool available: device?.isLaptopBattery ?? false
    readonly property real percentage: device?.percentage ?? 1          // 0–1
    readonly property int state: device?.state ?? UPowerDeviceState.Unknown
    readonly property bool charging: state === UPowerDeviceState.Charging
    readonly property bool full: state === UPowerDeviceState.FullyCharged
    readonly property bool pluggedIn: !UPower.onBattery
    readonly property bool low: available && !pluggedIn && percentage <= 0.2
    readonly property bool critical: available && !pluggedIn && percentage <= 0.1
    readonly property real timeToEmpty: device?.timeToEmpty ?? 0         // seconds
    readonly property real timeToFull: device?.timeToFull ?? 0

    readonly property string icon: {
        if (charging || (pluggedIn && !full)) return "battery_charging_full";
        if (pluggedIn) return "battery_full";
        const steps = ["battery_0_bar", "battery_1_bar", "battery_2_bar", "battery_3_bar",
                       "battery_4_bar", "battery_5_bar", "battery_6_bar", "battery_full"];
        return steps[Math.min(7, Math.floor(percentage * 8))];
    }

    function formatDuration(sec) {
        if (!sec || sec <= 0) return "";
        const h = Math.floor(sec / 3600), m = Math.round((sec % 3600) / 60);
        return h > 0 ? `${h}h ${m}m` : `${m}m`;
    }
}
