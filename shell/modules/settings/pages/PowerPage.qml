// Power: mode, battery, idle behaviour.
import QtQuick
import Quickshell.Services.UPower
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    title: "Power"

    Group {
        title: "Power mode"
        SetRow {
            icon: Power.icon
            title: "Mode"
            description: Power.saver ? "Battery saver also turns off blur" : "Balanced suits most days"
            Segmented {
                width: 330
                options: [{ id: "saver", label: "Saver" }, { id: "balanced", label: "Balanced" }, { id: "performance", label: "Performance" }]
                current: Power.profile === PowerProfile.PowerSaver ? "saver" : Power.profile === PowerProfile.Performance ? "performance" : "balanced"
                onPicked: id => PowerProfiles.profile = id === "saver" ? PowerProfile.PowerSaver
                                                     : id === "performance" ? PowerProfile.Performance : PowerProfile.Balanced
            }
        }
    }

    Group {
        title: "Battery"
        visible: Battery.available
        SetRow {
            icon: Battery.icon
            title: Math.round(Battery.percentage * 100) + "%"
            description: Battery.charging ? (Battery.timeToFull > 0 ? "Charging — full in " + Battery.formatDuration(Battery.timeToFull) : "Charging")
                       : Battery.pluggedIn ? "Plugged in"
                       : Battery.timeToEmpty > 0 ? Battery.formatDuration(Battery.timeToEmpty) + " remaining" : "On battery"
        }
        SetRow {
            icon: "health_and_safety"
            title: "Battery health"
            visible: UPower.displayDevice?.healthSupported ?? false
            description: Math.round(UPower.displayDevice?.healthPercentage ?? 0) + "% of original capacity"
        }
    }

    Group {
        title: "When idle"
        SetRow { icon: "brightness_low"; title: "Dim the screen"; description: "After 4 minutes" }
        SetRow { icon: "lock"; title: "Lock"; description: "After 5 minutes, and always before sleep" }
        SetRow { icon: "monitor"; title: "Turn off the screen"; description: "After 5½ minutes" }
        SetRow { icon: "bedtime"; title: "Sleep"; description: "After 15 minutes · fullscreen video and games keep the screen awake" }
    }
}
