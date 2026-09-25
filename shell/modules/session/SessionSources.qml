// Shortcuts & IPC for the power menu (no UI).
//   Super+Escape, Ctrl+Alt+Delete  → lumen:powerMenu
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

Scope {
    GlobalShortcut { appid: "lumen"; name: "powerMenu"; description: "Power menu"; onPressed: Session.toggleMenu() }
    GlobalShortcut { appid: "lumen"; name: "controlCenter"; description: "Control centre"; onPressed: Sidebar.toggle() }

    IpcHandler {
        target: "session"
        function menu(): void { Session.toggleMenu(); }
        function lock(): void { Session.run("lock"); }
    }

    // Keep services that act on their own alive from the start:
    // night light restores its state; battery saver applies its blur rule.
    Component.onCompleted: { NightLight.enabled; Power.saver; }
}
