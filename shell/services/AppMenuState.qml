pragma Singleton
// Keyboard/IPC entry to the bar's app menu (Super+Alt+Enter). Each screen's
// AppMenu listens and opens only if it owns the focused window.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    signal toggleRequested()
    GlobalShortcut { appid: "lumen"; name: "appMenu"; description: "Menu of the focused app"; onPressed: root.toggleRequested() }
    IpcHandler { target: "appMenu"; function toggle(): void { root.toggleRequested(); } }
}
