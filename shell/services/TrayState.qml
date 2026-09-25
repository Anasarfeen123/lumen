pragma Singleton
// Opens the tray drawer (apps running in the background) on one screen.
// Sources: the tray button, right-click on the workspaces pill, right-click
// on the resting island, Super+Alt+T, `ipc call tray toggle`.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    signal toggleRequested(string monitor)
    // Empty monitor → the focused one
    function toggle(monitor) { root.toggleRequested(monitor || (Hyprland.focusedMonitor?.name ?? "")); }
    GlobalShortcut { appid: "lumen"; name: "tray"; description: "Apps running in the background"; onPressed: root.toggle("") }
    IpcHandler { target: "tray"; function toggle(): void { root.toggle(""); } }
}
