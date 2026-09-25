//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env LUMEN_SETTINGS_APP=1

// Lumen Settings — its own process. Started by the main shell (Super+I, the
// control centre's ⚙) via SettingsState.launch(); quits when its window closes.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.settings

ShellRoot {
    SettingsWindow {}

    Component.onCompleted: SettingsState.open = true

    // Register as this session's settings app (see SettingsState.launch)
    Process {
        running: true
        command: ["sh", "-c", 'echo "$PPID" > "$1"', "sh", SettingsState.pidFile]
    }
    Connections {
        target: SettingsState
        function onOpenChanged() { if (!SettingsState.open) Qt.quit(); }
    }

    IpcHandler {
        target: "settings"
        function open(page: string): void { SettingsState.show(page); }
        function close(): void { SettingsState.open = false; }
    }
}
