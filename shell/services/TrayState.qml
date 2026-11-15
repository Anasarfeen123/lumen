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
    // The apps in the tray, once each. An app that restarts (ytm-rs after an
    // update) can leave its old entry behind in the shell's list after its
    // registration is gone (ytm-rs showed three times: two entries from a
    // process that had exited, one live): the newest entry per app wins.
    readonly property var items: {
        const all = SystemTray.items.values, seen = new Set(), out = [];
        for (let i = all.length - 1; i >= 0; i--) {
            // by app: ids can carry the process ("tray-icon tray app 494113-1"), so the
            // title, or the id without its numbers
            const it = all[i], key = String(it.title || it.tooltipTitle || String(it.id ?? "").replace(/[\s\d_-]+$/, "")).toLowerCase();
            if (key && seen.has(key)) continue;
            seen.add(key);
            out.unshift(it);
        }
        return out;
    }
    // Empty monitor → the focused one
    function toggle(monitor) {
        // Say so rather than do nothing
        if (root.items.length === 0) { Island.system("apps", "Nothing in the background", "No app is using the tray"); return; }
        root.toggleRequested(monitor || (Hyprland.focusedMonitor?.name ?? ""));
    }
    GlobalShortcut { appid: "lumen"; name: "tray"; description: "Apps running in the background"; onPressed: root.toggle("") }
    IpcHandler {
        target: "tray"
        function toggle(): void { root.toggle(""); }
        function menu(index: int): void { root.menuRequested(index); }      // open app #index's menu in the drawer
        // what the shell holds, duplicates included: [{ id, title, status }]
        function list(): string { return JSON.stringify(SystemTray.items.values.map(i => ({ id: i.id, title: i.title || i.tooltipTitle, status: i.status }))); }
    }
}
