//@ pragma UseQApplication
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env LUMEN_SETTINGS_APP=1
//@ pragma Env LUMEN_NOTES_APP=1

// Lumen Notes — its own process, like Settings. Started by the main shell
// (Super+O, Super+Shift+O for a new note) via Notes.launch(); quits when its
// window closes. LUMEN_NOTES_OPEN: "" (the list), "+new", or a file name.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.notes

ShellRoot {
    NotesWindow { id: win; initial: Quickshell.env("LUMEN_NOTES_OPEN") ?? "" }

    // Register as this session's Notes app (see Notes.launch)
    Process {
        running: true
        command: ["sh", "-c", 'echo "$PPID" > "$1"', "sh", Notes.pidFile]
    }

    IpcHandler {
        target: "notesApp"
        function open(what: string): void { win.handle(what); }
    }
}
