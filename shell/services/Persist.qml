pragma Singleton

// Small shell settings that survive restarts (~/.local/state/lumen/shell.json).
// Add a property here and it is saved automatically.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    // True only for the main shell of a real session: automations that change
    // shared settings (schedules, night light, wallpaper) run here, never in
    // the Settings app or in nested test sessions.
    readonly property bool automates: Quickshell.env("LUMEN_SETTINGS_APP") !== "1" && !Quickshell.env("LUMEN_NESTED")
    readonly property alias data: adapter

    // Test sessions (nested, LUMEN_NESTED) keep their own copy of these
    // preferences, started from yours, so trying things there never changes
    // your real desktop (e.g. a Halo provider picked while testing).
    readonly property string dir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/lumen"
    readonly property bool testing: !!Quickshell.env("LUMEN_NESTED")
    property bool seeded: false
    Process {
        id: seedTestCopy
        command: ["sh", "-c", 'mkdir -p "$1" && [ ! -e "$1/shell-test.json" ] && cp "$1/shell.json" "$1/shell-test.json" 2>/dev/null; true', "sh", root.dir]
        onExited: prefs.reload()
    }
    FileView {
        id: prefs
        path: root.dir + (root.testing ? "/shell-test.json" : "/shell.json")
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => {
            if (error !== FileViewError.FileNotFound) return;
            if (root.testing && !root.seeded) { root.seeded = true; seedTestCopy.running = true; }
            else writeAdapter();
        }

        JsonAdapter {
            id: adapter
            property bool nightLight: false
            property int nightLightTemp: 4500
            // Bar & island (Lumen Settings → Bar & Island)
            property bool islandDate: true
            property bool islandWorkspace: true
            property string phoneNotifications: "calls"  // KDE Connect mirrors: "calls" | "all" | "none"
            property bool linkBluetoothAuto: true     // Lumen Link: bring the phone's Bluetooth network up by itself
            property string islandScroll: "timeline"   // scroll on the island: "timeline" | "volume"
            property bool hotCornerLeft: true
            property bool hotCornerRight: true
            // Look & sound (Lumen Settings → Appearance)
            property string iconTheme: "McMojave-circle-dark"   // "system" = the system theme
            property bool uiSounds: true
            property bool lyrics: true            // island lyrics from lrclib.net (sends title + artist)
            // Notifications (Lumen Settings → Notifications)
            property bool notifBanners: true      // show arrivals in the island
            property var mutedApps: []            // app names: history only, no banner or sound
            property var clipPins: []
            property var seenDevices: []          // USB / Bluetooth / display ids already announced as "New"             // pinned clipboard items: { kind: "text"|"image", text, file }
            property var weatherPlace: null       // { name, lat, lon } — Open-Meteo, set by you
            property string aiProvider: "off"     // "off" | "anthropic" | "ollama"
            property string aiModel: ""           // empty = the provider default
            property var focusSchedule: ({ sleep: { on: false, from: "23:00", to: "07:00" }, work: { on: false, from: "09:00", to: "17:00", weekdays: true } })
            property var focusAllow: []           // apps that may interrupt any Focus mode
            property string nightLightAuto: "off" // "off" | "sun" (sunset→sunrise) | "custom"
            property string nightLightFrom: "21:00"
            property string nightLightTo: "07:00"
            property bool wallpaperByTime: false
            property bool adaptiveUi: true       // evening: warmer accent, calmer motion (after local sunset)
            property string musicApp: "auto"      // music scratchpad: "auto" | "ytmusic" | "spotify"
            property var wallpaperSlots: ({ dawn: "", day: "", dusk: "", night: "" })
            // Lock screen widgets (Lumen Settings → Lock screen)
            property bool lockMedia: true
            property bool lockBattery: true
            property bool lockCalendar: true
            property bool lockNotifications: true
            property bool lockPhone: true             // your phone (Lumen Link): battery, linked
            property bool lockMessages: true          // unread chats — counts only, never names or text
            // ── Screen time (services/ScreenTime.qml) ──
            property bool screenTime: true        // record which apps you use, on this machine only
        }
    }
}
