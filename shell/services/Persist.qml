pragma Singleton

// Small shell settings that survive restarts (~/.local/state/lumen/shell.json).
// Add a property here and it is saved automatically.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property alias data: adapter

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/lumen/shell.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }

        JsonAdapter {
            id: adapter
            property bool nightLight: false
            property int nightLightTemp: 4500
            // Bar & island (Lumen Settings → Bar & Island)
            property bool islandDate: true
            property bool islandWorkspace: true
            property bool hotCornerLeft: true
            property bool hotCornerRight: true
            // Look & sound (Lumen Settings → Appearance)
            property string iconTheme: "McMojave-circle-dark"   // "system" = the system theme
            property bool uiSounds: true
            // Notifications (Lumen Settings → Notifications)
            property bool notifBanners: true      // show arrivals in the island
            property var mutedApps: []            // app names: history only, no banner or sound
            property var clipPins: []             // pinned clipboard items: { kind: "text"|"image", text, file }
            property var weatherPlace: null       // { name, lat, lon } — Open-Meteo, set by you
            // Lock screen widgets (Lumen Settings → Lock screen)
            property bool lockMedia: true
            property bool lockBattery: true
            property bool lockCalendar: true
            property bool lockNotifications: true
        }
    }
}
