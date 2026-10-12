//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env LUMEN_SETTINGS_APP=1

// Lumen Monitor — its own process, like Settings (Ctrl+Shift+Esc). Samples
// only while its window is open; quits when it closes.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.monitor

ShellRoot {
    MonitorWindow { id: win }

    // One per session: a second Ctrl+Shift+Esc raises this one (bin/lumen-monitor)
    Process {
        running: true
        command: ["sh", "-c", 'echo "$PPID" > "${XDG_RUNTIME_DIR:-/tmp}/lumen-monitor-${HYPRLAND_INSTANCE_SIGNATURE:-x}.pid"']
    }
    IpcHandler {
        target: "monitorApp"
        // "performance", or "performance/mem" for one resource (cpu · mem · disk:<dev> · net:<if> · gpu:<card> · battery)
        function open(tab: string): void { if (tab) win.go(tab); }
    }
}
