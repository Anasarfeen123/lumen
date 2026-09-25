// Shortcuts & IPC for wallpapers (no UI).
//   Ctrl+Super+T  picker · Ctrl+Super+Alt+T  shuffle
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

Scope {
    GlobalShortcut { appid: "lumen"; name: "wallpapers"; description: "Wallpaper picker"; onPressed: Wallpapers.toggle() }
    GlobalShortcut { appid: "lumen"; name: "wallpaperRandom"; description: "Random wallpaper"; onPressed: { Wallpapers.refresh(); Wallpapers.random(); } }

    IpcHandler {
        target: "wallpapers"
        function toggle(): void { Wallpapers.toggle(); }
        function random(): void { Wallpapers.random(); }
    }

    Component.onCompleted: { Wallpapers.refresh(); CheatsheetState.open; }   // instantiate the cheatsheet shortcut
}
