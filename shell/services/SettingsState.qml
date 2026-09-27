pragma Singleton
// Lumen Settings state. Settings runs as its OWN Quickshell process
// (shell/settings.qml) — crash-isolated, and using no memory while closed.
//   From the main shell: SettingsState.launch(page) starts it or, if it is
//   already running, switches its page and focuses it.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    property bool open: false
    property string page: Quickshell.env("LUMEN_SETTINGS_PAGE") || "appearance"

    // In sidebar order, under their group headings
    readonly property var pages: [
        { group: "Personalise", id: "appearance",    icon: "palette",             label: "Appearance",          keys: "theme dark light accent colour transparency glass blur motion clock 12 24 icons sounds" },
        { group: "Personalise", id: "wallpaper",     icon: "wallpaper",           label: "Wallpaper",           keys: "background picture shuffle match accent" },
        { group: "Personalise", id: "bar",           icon: "top_panel_open",      label: "Bar & Island",        keys: "island date workspace hot corners" },
        { group: "Personalise", id: "windows",       icon: "select_window",       label: "Windows",             keys: "gaps corners rounding border animation speed focus follows mouse" },
        { group: "Connections", id: "network",       icon: "wifi",                label: "Network",             keys: "wifi wi-fi internet airplane vpn warp cloudflare dns" },
        { group: "Connections", id: "bluetooth",     icon: "bluetooth",           label: "Bluetooth",           keys: "devices headphones pair connect battery" },
        { group: "Connections", id: "phone",         icon: "phonelink",           label: "Lumen Link",          keys: "phone link kde connect android iphone pair find ring send file clipboard sync usb tethering hotspot address bluetooth" },
        { group: "Connections", id: "whatsapp",      icon: "forum",               label: "WhatsApp",            keys: "whatsapp messages chat reply inbox whatsie contacts focus mute previews calls" },
        { group: "Devices", id: "sound",         icon: "volume_up",           label: "Sound",               keys: "volume output input microphone speaker headphones music lyrics" },
        { group: "Devices", id: "display",       icon: "brightness_6",        label: "Display",             keys: "brightness night light warmth" },
        { group: "Devices", id: "keyboard",      icon: "keyboard",            label: "Keyboard & Gestures", keys: "shortcuts keybinds cheatsheet touchpad gestures corners" },
        { group: "Devices", id: "power",         icon: "battery_charging_80", label: "Power",               keys: "battery saver performance idle sleep suspend lock timeout screen off charge limit health" },
        { group: "Focus & privacy", id: "notifications", icon: "notifications",       label: "Notifications",       keys: "focus do not disturb dnd banners mute apps sound history" },
        { group: "Focus & privacy", id: "lock",          icon: "lock",                label: "Lock screen",         keys: "widgets password unlock" },
        { group: "Focus & privacy", id: "faceid",        icon: "face",                label: "Face ID",             keys: "face unlock gaze camera liveness anti photo calibrate strictness" },
        { group: "Focus & privacy", id: "security",      icon: "shield",              label: "Security",            keys: "security firewall ssh secure boot encryption selinux logins privacy" },
        { group: "System", id: "ai",            icon: "auto_awesome",        label: "Halo",                keys: "halo ai assistant ask claude anthropic ollama local model api key chat" },
        { group: "System", id: "system",        icon: "monitor_heart",       label: "System",              keys: "system inspector hardware cpu gpu nvidia amd memory ram disk storage battery temperature kernel" },
        { group: "System", id: "updates",       icon: "system_update",       label: "Updates",             keys: "update upgrade dnf flatpak packages security software" },
        { group: "System", id: "advanced",      icon: "tune",                label: "Advanced",            keys: "advanced config files local.lua session.env logs journal verify doctor reset reload rebuild developer debug version" },
        { group: "System", id: "backup",        icon: "backup",              label: "Backup & recovery",   keys: "backup restore snapshot rsync drive usb external files recovery safe mode reset settings config" },
        { group: "System", id: "about",         icon: "info",                label: "About",               keys: "version system hardware kernel hyprland" }
    ]
    property string search: ""
    readonly property var visiblePages: {
        const q = search.trim().toLowerCase();
        if (q === "") return pages;
        return pages.filter(p => (p.label + " " + p.keys).toLowerCase().includes(q));
    }

    function show(p) { if (p && pages.some(x => x.id === p)) page = p; open = true; }
    function toggle() { open = !open; }

    // One settings app per Hyprland session, found by its pid file — never
    // another session's (several Lumen sessions can run at once).
    readonly property string pidFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lumen-settings-"
                                      + (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "default") + ".pid"

    // Main shell → the settings app (reuse this session's, or start it)
    function launch(p) {
        Quickshell.execDetached(["sh", "-c",
            'pid=$(cat "$3" 2>/dev/null) && tr "\\0" " " < "/proc/$pid/cmdline" 2>/dev/null | grep -q settings.qml && ' +
            '{ qs ipc --pid "$pid" call settings open "$2" >/dev/null 2>&1; hyprctl dispatch "hl.dsp.focus({ window = \\"pid:$pid\\" })" >/dev/null 2>&1; exit 0; }; ' +
            'LUMEN_SETTINGS_PAGE="$2" exec qs -p "$1/shell/settings.qml"', "sh", Theme.lumenRoot, p || "appearance", pidFile]);
    }
    // Settings app → main shell (wallpaper picker, cheatsheet live there)
    function shellCall(target, fn) {
        Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen-shell-ipc", target, fn]);
    }

    // Colour previews for theme/accent pickers (generated by theme/build.py)
    property var previews: ({ themes: [], accents: [] })
    FileView {
        path: Theme.lumenRoot + "/generated/previews.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { root.previews = JSON.parse(text()); } catch (e) {} }
    }

    function lumen(args) { Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen"].concat(args)); }

}
