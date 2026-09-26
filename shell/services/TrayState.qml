pragma Singleton
// Opens the tray drawer (apps running in the background) on one screen.
// Sources: the tray button, right-click on the workspaces pill, right-click
// on the resting island, Super+Alt+T, `ipc call tray toggle`.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.SystemTray

Singleton {
    id: root
    signal toggleRequested(string monitor)
    signal menuRequested(int index)
    // Empty monitor → the focused one
    function toggle(monitor) {
        // Say so rather than do nothing
        if (SystemTray.items.values.length === 0) { Island.system("apps", "Nothing in the background", "No app is using the tray"); return; }
        root.toggleRequested(monitor || (Hyprland.focusedMonitor?.name ?? ""));
    }
    GlobalShortcut { appid: "lumen"; name: "tray"; description: "Apps running in the background"; onPressed: root.toggle("") }
    IpcHandler {
        target: "tray"
        function toggle(): void { root.toggle(""); }
        function menu(index: int): void { root.menuRequested(index); }      // open app #index's menu in the drawer
    }
}
