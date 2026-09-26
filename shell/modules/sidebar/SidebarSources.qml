// Shortcuts & IPC for the sidebar and notifications (no UI).
//   Super+N  sidebar · Super+Alt+N  Do Not Disturb · Super+Alt+Shift+N  clear all
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

Scope {
    GlobalShortcut { appid: "lumen"; name: "sidebar"; description: "Notification centre"; onPressed: Sidebar.toggle("notifications") }
    GlobalShortcut { appid: "lumen"; name: "dnd"; description: "Toggle Do Not Disturb"; onPressed: Notifications.setDnd(!Notifications.dnd) }
    GlobalShortcut { appid: "lumen"; name: "clearNotifications"; description: "Clear all notifications"; onPressed: Notifications.clearAll() }

    IpcHandler {
        target: "notifications"
        function toggleDnd(): void { Notifications.setDnd(!Notifications.dnd); }
        function clear(): void { Notifications.clearAll(); }
        function count(): int { return Notifications.count; }
    }
    // Dev only (LUMEN_DEV): a local notification that never touches the bus
    IpcHandler {
        target: "notifyTest"
        enabled: Quickshell.env("LUMEN_DEV") === "1"
        function add(app: string, summary: string, body: string): void {
            Notifications.receiveMirrored([app, 0, "", summary, body, [], { urgency: { data: 1 } }, -1]);
        }
    }
    IpcHandler {
        target: "sidebar"
        function toggle(): void { Sidebar.toggle(); }
        function open(): void { Sidebar.show(); }
        function controls(): void { Sidebar.toggle("controls"); }
        function notifications(): void { Sidebar.toggle("notifications"); }
        function close(): void { Sidebar.hide(); }
    }

    // Make sure the daemon starts with the shell, not on first use
    Component.onCompleted: Notifications.count
}
