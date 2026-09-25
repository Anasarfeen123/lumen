// Power: mode, battery, idle behaviour.
import QtQuick
import Quickshell.Services.UPower
import Quickshell.Io
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
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

    // Battery charge limit (root helper via pkexec; re-applied at every boot)
    property int chargeLimit: 100
    property bool limitSupported: false
    property bool applying: false
    Process {
        id: limitRead
        running: true
        command: ["sh", "-c", "for b in /sys/class/power_supply/BAT*; do [ -r \"$b/charge_control_end_threshold\" ] && cat \"$b/charge_control_end_threshold\" && exit 0; done; exit 1"]
        stdout: StdioCollector { onStreamFinished: { const v = parseInt(text); if (v > 0) { chargeLimit = v; limitSupported = true; } } }
    }
    Process {
        id: limitSet
        onExited: { applying = false; limitRead.running = true; }
    }

    Group {
        title: "Battery care"
        visible: limitSupported
        SetRow {
            icon: "eco"
            title: "Charge limit"
            description: chargeLimit >= 100 ? "Charges to 100 %."
                : "Stops at " + chargeLimit + " % — gentler on a battery that lives on the charger" + (Battery.pluggedIn && !Battery.charging && Battery.percentage * 100 >= chargeLimit - 1 ? " (paused now)" : "") + "."
            Segmented {
                width: 300
                enabled: !applying
                options: [{ id: "100", label: "Full" }, { id: "90", label: "90 %" }, { id: "80", label: "80 %" }, { id: "60", label: "60 %" }]
                current: String(chargeLimit)
                onPicked: id => {
                    applying = true;
                    limitSet.command = ["pkexec", Theme.lumenRoot + "/scripts/power-admin.sh", "charge-limit", id];
                    limitSet.running = true;
                }
            }
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
