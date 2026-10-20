//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env LUMEN_SETTINGS_APP=1
//@ pragma Env LUMEN_AMAZECC_APP=1

// AmazeCC — your college (VTOP, through your own amazecc-api) as an app: its
// own process, like Settings and Notes. Started by the main shell (Ctrl+Super+A,
// search, Halo "open AmazeCC") via Amazecc.launch(); quits when its window
// closes. LUMEN_AMAZECC_PAGE: overview | timetable | attendance | marks |
// exams | grades | campus.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.amazecc

ShellRoot {
    AmazeccWindow { id: win; page: Quickshell.env("LUMEN_AMAZECC_PAGE") || "overview" }

    // Register as this session's AmazeCC app (see Amazecc.launch)
    Process {
        running: true
        command: ["sh", "-c", 'echo "$PPID" > "$1"', "sh", Amazecc.pidFile]
    }

    IpcHandler {
        target: "amazeccApp"
        function open(page: string): void { if (page) win.page = page; }
        function close(): void { Qt.quit(); }
    }
}
