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
        { group: "Personalise", id: "appearance", icon: "palette",             label: "Appearance",          keys: "theme dark light accent colour transparency glass blur motion clock 12 24 icons sounds" },
        { group: "Personalise", id: "wallpaper", icon: "wallpaper",           label: "Wallpaper",           keys: "background picture shuffle match accent" },
        { group: "Personalise", id: "bar", icon: "top_panel_open",      label: "Bar & Island",        keys: "island date workspace hot corners" },
        { group: "Personalise", id: "windows", icon: "select_window",       label: "Windows",             keys: "gaps corners rounding border animation speed focus follows mouse" },
        { group: "Halo", id: "ai", icon: "auto_awesome",        label: "General",             keys: "halo on off name character personality chattiness jarvis mascot face island little things breaks birthday" },
        { group: "Halo", id: "ai-models", icon: "neurology",           label: "Models",              keys: "halo ai provider model claude anthropic openai gemini ollama local cloud api key server download privacy" },
        { group: "Halo", id: "ai-voice", icon: "graphic_eq",          label: "Voice",               keys: "halo voice talk speak speech whisper piper wake word hey halo listen microphone natural voice rate" },
        { group: "Halo", id: "ai-abilities", icon: "touch_app",         label: "Abilities",           keys: "halo agent doing things hands pointer click type memory remember routines watches workflows accessibility terminal" },
        { group: "Halo", id: "ai-day", icon: "wb_twilight",         label: "Your day",            keys: "halo wrap-up morning brief evening away reminders calendar email mail ical imap doctor battery health" },
        { group: "Connections", id: "network", icon: "wifi",                label: "Network",             keys: "wifi wi-fi internet airplane vpn warp cloudflare dns" },
        { group: "Connections", id: "bluetooth", icon: "bluetooth",           label: "Bluetooth",           keys: "devices headphones pair connect battery" },
        { group: "Connections", id: "phone", icon: "phonelink",           label: "Lumen Link",          keys: "phone link kde connect android iphone pair find ring send file clipboard sync usb tethering hotspot address bluetooth" },
        { group: "Apps & services", id: "apps", icon: "apps",                label: "Default apps",        keys: "default apps browser files file manager editor code terminal system monitor brave firefox dolphin kitty" },
        { group: "Apps & services", id: "notes", icon: "edit_note",           label: "Notes",               keys: "notes notepad markdown write sync phone syncthing obsidian scratchpad folder" },
        { group: "Apps & services", id: "whatsapp", icon: "forum",               label: "WhatsApp",            keys: "whatsapp messages chat reply inbox whatsie contacts focus mute previews calls" },
        { group: "Apps & services", id: "amazecc", icon: "school",              label: "AmazeCC",             keys: "amazecc vit vtop college university timetable classes attendance marks grades exams cat fat schedule semester reminders" },
        { group: "Devices", id: "display", icon: "brightness_6",        label: "Display",             keys: "brightness night light warmth" },
        { group: "Devices", id: "sound", icon: "volume_up",           label: "Sound",               keys: "volume output input microphone speaker headphones music lyrics" },
        { group: "Devices", id: "keyboard", icon: "keyboard",            label: "Keyboard & Gestures", keys: "shortcuts keybinds cheatsheet touchpad gestures corners" },
        { group: "Devices", id: "mouse", icon: "mouse",               label: "Mouse & touchpad",    keys: "mouse touchpad pointer speed acceleration tap click natural scrolling scroll speed palm typing repeat delay rate keyboard layout language gestures left handed" },
        { group: "Devices", id: "power", icon: "battery_charging_80", label: "Power",               keys: "battery saver performance idle sleep suspend lock timeout screen off charge limit health" },
        { group: "Privacy", id: "notifications", icon: "notifications",       label: "Notifications",       keys: "focus do not disturb dnd banners mute apps sound history" },
        { group: "Privacy", id: "lock", icon: "lock",                label: "Lock screen",         keys: "widgets password unlock" },
        { group: "Privacy", id: "faceid", icon: "face",                label: "Face ID",             keys: "face unlock gaze camera liveness anti photo calibrate strictness" },
        { group: "Privacy", id: "security", icon: "shield",              label: "Security",            keys: "security firewall ssh secure boot encryption selinux logins privacy" },
        { group: "System", id: "system", icon: "monitor_heart",       label: "System",              keys: "system inspector hardware cpu gpu nvidia amd memory ram disk storage battery temperature kernel" },
        { group: "System", id: "updates", icon: "system_update",       label: "Updates",             keys: "update upgrade dnf flatpak packages security software" },
        { group: "System", id: "backup", icon: "backup",              label: "Backup & recovery",   keys: "backup restore snapshot rsync drive usb external files recovery safe mode reset settings config" },
        { group: "System", id: "advanced", icon: "tune",                label: "Advanced",            keys: "advanced config files local.lua session.env logs journal verify doctor reset reload rebuild developer debug version" },
        { group: "System", id: "about", icon: "info",                label: "About",               keys: "version system hardware kernel hyprland" }
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
