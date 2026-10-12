pragma Singleton

// Power profile (tuned-ppd / power-profiles-daemon over D-Bus) and battery
// saver. Power-saver mode also turns off blur (DESIGN.md §6.2) — the single
// most expensive effect on the iGPU.
//
// Also watches the NVIDIA GPU's runtime power management (sysfs only — reading
// it never wakes the GPU): when the driver gets stuck ("error"), the GPU stays
// fully awake and drains the battery, so the island offers a one-click fix
// (scripts/power-admin.sh dgpu-pm-reset, through pkexec).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import qs.theme

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

    // ── NVIDIA GPU stuck awake ──
    property string dgpu: ""                // "", active, suspended, error…
    property int dgpuErrors: 0              // checks in a row that said "error"
    property real dgpuWarned: 0
    readonly property bool dgpuStuck: dgpu === "error"
    function checkDgpu() { if (!dgpuProbe.running) dgpuProbe.running = true; }
    Process {
        id: dgpuProbe
        command: ["sh", "-c", 'for d in /sys/bus/pci/devices/*; do [ "$(cat "$d/vendor" 2>/dev/null)" = 0x10de ] || continue; case $(cat "$d/class") in 0x03*) cat "$d/power/runtime_status"; exit;; esac; done']
        stdout: StdioCollector {
            onStreamFinished: {
                root.dgpu = text.trim();
                root.dgpuErrors = root.dgpu === "error" ? root.dgpuErrors + 1 : 0;
                // Twice in a row (it isn't a passing state), at most every 6 hours
                if (root.dgpuErrors >= 2 && Date.now() - root.dgpuWarned > 6 * 3600000 && Persist.automates) {
                    root.dgpuWarned = Date.now();
                    Island.device("dgpu-stuck", {
                        icon: "battery_alert", badge: "",
                        title: "NVIDIA GPU is stuck awake",
                        detail: "Its power management failed, so it's using the battery for nothing",
                        actions: [{ icon: "build", label: "Fix", cmd: ["pkexec", Theme.lumenRoot + "/scripts/power-admin.sh", "dgpu-pm-reset"] },
                                  { icon: "monitor_heart", label: "Details", cmd: [Theme.lumenRoot + "/bin/lumen-monitor", "performance/gpu:card0"] }]
                    });
                }
            }
        }
    }
    Timer { interval: 300000; repeat: true; triggeredOnStart: true; running: Persist.automates; onTriggered: root.checkDgpu() }
    function fixDgpu() { Quickshell.execDetached(["pkexec", Theme.lumenRoot + "/scripts/power-admin.sh", "dgpu-pm-reset"]); dgpuErrors = 0; recheck.restart(); }
    Timer { id: recheck; interval: 8000; onTriggered: root.checkDgpu() }
}
