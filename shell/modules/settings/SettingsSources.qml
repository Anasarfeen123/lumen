// Main-shell side of Lumen Settings (no UI): Super+I and IPC launch the
// separate settings app (shell/settings.qml).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.services

Scope {
    GlobalShortcut { appid: "lumen"; name: "settings"; description: "Lumen Settings"; onPressed: SettingsState.launch("") }
    IpcHandler {
        target: "lumenSettings"
        function open(page: string): void { SettingsState.launch(page); }
    }
}
