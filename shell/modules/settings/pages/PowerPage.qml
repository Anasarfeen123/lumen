// Power: mode, battery, idle behaviour.
import QtQuick
import Quickshell
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
            description: Power.saver ? "Longer battery · also turns off blur"
                : Power.profile === PowerProfile.Performance ? "Full speed · more heat and fan" : "Balanced suits most days"
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
                       : Battery.forecastText ? "About " + Battery.forecastText + " left at this rate" : "On battery"
        }
        SetRow {
            icon: "insights"
            title: "Usual battery life"
            description: Battery.usualText ? "A full charge usually lasts about " + Battery.usualText + ", from your last 7 days. Lumen warns when you should plug in (45 and 15 minutes left)."
                                           : "Lumen learns how long your battery lasts as you use it on battery, and warns when you should plug in."
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
            description: chargeLimit >= 100 ? "Charges to 100%."
                : "Stops at " + chargeLimit + "% — gentler on a battery that lives on the charger" + (Battery.pluggedIn && !Battery.charging && Battery.percentage * 100 >= chargeLimit - 1 ? " (paused now)" : "") + "."
            Segmented {
                width: 300
                enabled: !applying
                options: [{ id: "100", label: "Full" }, { id: "90", label: "90%" }, { id: "80", label: "80%" }, { id: "60", label: "60%" }]
                current: String(chargeLimit)
                onPicked: id => {
                    applying = true;
                    limitSet.command = ["pkexec", Theme.lumenRoot + "/scripts/power-admin.sh", "charge-limit", id];
                    limitSet.running = true;
                }
            }
        }
    }

    // ── The NVIDIA GPU and the HDMI port ──
    // On this kind of laptop the HDMI port is wired to the NVIDIA GPU, so the
    // session opens that GPU to drive it — and it then wakes every few seconds.
    // LUMEN_DGPU=off in session.env (bin/lumen-session) leaves it out at the next
    // login: the GPU sleeps, the HDMI port is off. lumen-dgpu <app> still works.
    readonly property string sessionEnv: Theme.lumenRoot + "/session.env"
    property string envText: ""
    property bool dgpuInSession: false            // this session was started with it
    property bool dgpuPresent: false
    readonly property bool hdmiOff: /^\s*LUMEN_DGPU=off\s*$/m.test(envText)
    FileView { id: envFile; path: page.sessionEnv; watchChanges: true; printErrors: false
               onFileChanged: reload(); onLoaded: page.envText = text(); onLoadFailed: page.envText = "" }
    Process {
        running: true
        command: ["sh", "-c", 'for d in /sys/bus/pci/devices/*; do [ "$(cat $d/vendor)" = 0x10de ] && case $(cat $d/class) in 0x03*) echo present;; esac; done; '
                 + 'p=$(pgrep -u "$(id -u)" -x Hyprland | head -1); [ -n "$p" ] && tr "\\0" "\\n" < /proc/$p/environ | grep "^AQ_DRM_DEVICES="']
        stdout: StdioCollector {
            onStreamFinished: {
                page.dgpuPresent = /present/.test(text);
                const m = /AQ_DRM_DEVICES=(.*)/.exec(text);
                page.dgpuInSession = !!m && m[1].split(":").filter(x => x).length > 1;
            }
        }
    }
    Component.onCompleted: Power.checkDgpu()
    function setHdmi(on) {
        Quickshell.execDetached(["sh", "-c", 'f="$1"; touch "$f"; sed -i "/^[[:space:]]*LUMEN_DGPU=/d" "$f"; [ "$2" = off ] && printf "LUMEN_DGPU=off\\n" >> "$f"; true',
                                 "sh", sessionEnv, on ? "on" : "off"]);
    }
    Group {
        title: "NVIDIA GPU"
        visible: page.dgpuPresent
        SetRow {
            icon: Power.dgpu === "suspended" ? "bedtime" : Power.dgpu === "error" ? "battery_alert" : "bolt"
            title: Power.dgpu === "suspended" ? "Asleep — saving battery" : Power.dgpu === "error" ? "Stuck awake — restart to recover" : "Awake"
            description: page.dgpuInSession
                ? "This session drives the HDMI port with it, which wakes it every few seconds even when nothing is plugged in"
                : "Not used by the desktop this session (HDMI port off); apps you start with lumen-dgpu still use it"
        }
        SetRow {
            icon: "settings_input_hdmi"
            title: "HDMI port"
            description: (page.hdmiOff ? "Off from the next login — the NVIDIA GPU can sleep. "
                                       : "On — needed for an external monitor or projector. ")
                         + (page.hdmiOff === !page.dgpuInSession ? "" : "Log out and back in to apply.")
            Row {
                spacing: Theme.space.s2
                Button { visible: page.hdmiOff === page.dgpuInSession; text: "Log out…"; onActivated: SettingsState.shellCall("session", "menu") }
                LSwitch { checked: !page.hdmiOff; onToggled: page.setHdmi(!checked ? true : false) }
            }
        }
    }

    // Idle timings → generated hypridle.conf (lumen set idle_lock|idle_sleep)
    readonly property var idle: Theme.tokens.idle ?? { lock: "5", sleep: "15" }
    function mins(v) { return v === "60" ? "1 hour" : v + " minutes"; }

    Group {
        title: "When idle"
        SetRow {
            icon: "lock"
            title: "Lock after"
            description: idle.lock === "never" ? "Never on its own — still locks before sleep and with Super+L"
                : "Dims a minute before · screen off 30 s after"
            Segmented {
                width: 330
                options: [{ id: "2", label: "2 min" }, { id: "5", label: "5 min" }, { id: "10", label: "10 min" },
                          { id: "30", label: "30 min" }, { id: "never", label: "Never" }]
                current: idle.lock
                onPicked: id => SettingsState.lumen(["set", "idle_lock", id])
            }
        }
        SetRow {
            icon: "bedtime"
            title: "Sleep after"
            description: idle.sleep === "never" ? "Never sleeps on its own"
                : idle.sleep === "battery" ? "15 minutes, only when unplugged"
                : mins(idle.sleep) + " · fullscreen video and games keep it awake"
            Segmented {
                width: 330
                options: [{ id: "15", label: "15 min" }, { id: "30", label: "30 min" }, { id: "60", label: "1 h" },
                          { id: "battery", label: "Battery" }, { id: "never", label: "Never" }]
                current: idle.sleep
                onPicked: id => SettingsState.lumen(["set", "idle_sleep", id])
            }
        }
    }
}
