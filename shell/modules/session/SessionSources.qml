// Shortcuts & IPC for the power menu (no UI).
//   Super+Escape, Ctrl+Alt+Delete  → lumen:powerMenu
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services
import qs.theme

Scope {
    GlobalShortcut { appid: "lumen"; name: "powerMenu"; description: "Power menu"; onPressed: Session.toggleMenu() }
    GlobalShortcut { appid: "lumen"; name: "controlCenter"; description: "Control centre"; onPressed: Sidebar.toggle("controls") }

    IpcHandler {
        target: "session"
        function menu(): void { Session.toggleMenu(); }
        function lock(): void { Session.run("lock"); }
    }

    // Keep services that act on their own alive from the start:
    // night light restores its state; battery saver applies its blur rule.
    // Start these services with the shell (incl. the update checker)
    Component.onCompleted: { NightLight.enabled; Power.saver; Updates.count; Keyboard.caps; Downloads.dir; }
    // Evening look after local sunset (Theme.evening), if enabled
    Binding { target: Theme; property: "evening"; value: (Persist.data.adaptiveUi ?? true) && (Sun.phase === "night" || Sun.phase === "dusk") }
}
