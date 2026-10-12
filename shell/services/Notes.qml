pragma Singleton
// Lumen Notes — a folder of plain Markdown files (~/Notes by default), one
// note per file, so Syncthing can carry them to your phone and any Markdown
// app (Obsidian, Markor…) can open them. scripts/notes.py manages the folder;
// scripts/notes-sync.py sets up Syncthing.
//   main shell   Super+O opens the Notes app, Super+Shift+O a new note;
//                the planner's Notes card is ~/Notes/Scratchpad.md
//   Notes app    its own process (shell/notes.qml, like Settings): the list,
//                search, the open note — this singleton's `app` half
// Lumen's own preferences (pins, the folder) live in
// ~/.local/state/lumen/notes.json; the notes themselves never do.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root

    readonly property string script: Theme.lumenRoot + "/scripts/notes.py"
    readonly property string syncScript: Theme.lumenRoot + "/scripts/notes-sync.py"
    readonly property bool app: Quickshell.env("LUMEN_NOTES_APP") === "1"

    // ── preferences ──
    readonly property alias cfg: adapter
    FileView {
        path: Persist.dir + "/notes.json"
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }
        JsonAdapter {
            id: adapter
            property string dir: ""            // empty: ~/Notes
            property var pinned: []            // file names
            property string last: ""           // the note open last time
            property bool preview: false       // open notes formatted, not as Markdown source
        }
    }
    readonly property string dir: cfg.dir || (Quickshell.env("HOME") + "/Notes")
    readonly property string scratchFile: dir + "/Scratchpad.md"
    function pathOf(file) { return dir + "/" + file; }

    // ── the folder exists (and the planner's old scratchpad has moved in) ──
    property bool ready: false
    Process {
        running: true
        command: [root.script, "--dir", root.dir, "ensure"]
        onExited: root.ready = true
    }

    // ── opening the app (one per session, like Settings) ──
    readonly property string pidFile: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lumen-notes-" + (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "x") + ".pid"
    // what: "" (the list), "+new" (a new note), or a file name
    function launch(what) {
        Quickshell.execDetached(["sh", "-c",
            'pid=$(cat "$3" 2>/dev/null) && tr "\\0" " " < "/proc/$pid/cmdline" 2>/dev/null | grep -q notes.qml && ' +
            '{ qs ipc --pid "$pid" call notesApp open "$2" >/dev/null 2>&1; hyprctl dispatch "hl.dsp.focus({ window = \\"pid:$pid\\" })" >/dev/null 2>&1; exit 0; }; ' +
            'LUMEN_NOTES_OPEN="$2" exec qs -p "$1/shell/notes.qml"', "sh", Theme.lumenRoot, what ?? "", pidFile]);
    }
    // The shell owns the shortcuts (the app registering them too would clash)
    LazyLoader {
        active: !root.app && !Quickshell.env("LUMEN_SETTINGS_APP")
        Scope {
            GlobalShortcut { appid: "lumen"; name: "notes"; description: "Notes"; onPressed: root.launch("") }
            GlobalShortcut { appid: "lumen"; name: "notesNew"; description: "New note"; onPressed: root.launch("+new") }
        }
    }
    IpcHandler {
        target: "notes"
        enabled: !root.app
        function open(): void { root.launch(""); }
        function create(): void { root.launch("+new"); }
        function show(file: string): void { root.launch(file); }
    }

    // ═════ the Notes app's half ═════

    // ── the list ──
    property var all: []                 // [{ file, title, preview, mtime, words, open }]
    readonly property var sorted: {
        const pins = cfg.pinned ?? [];
        return all.slice().sort((a, b) => (pins.includes(b.file) - pins.includes(a.file)) || (b.mtime - a.mtime));
    }
    function isPinned(file) { return (cfg.pinned ?? []).includes(file); }
    function togglePin(file) {
        cfg.pinned = isPinned(file) ? cfg.pinned.filter(f => f !== file) : (cfg.pinned ?? []).concat([file]);
    }
    function refresh() { if (app && !listProc.running) listProc.running = true; else if (app) refreshAgain = true; }
    property bool refreshAgain: false
    Process {
        id: listProc
        command: [root.script, "--dir", root.dir, "list"]
        stdout: StdioCollector { onStreamFinished: { try { root.all = JSON.parse(text); } catch (e) {} } }
        onExited: if (root.refreshAgain) { root.refreshAgain = false; running = true; }
    }
    // Live: a note saved here, by Obsidian, or arriving from the phone
    Process {
        running: root.app && root.ready
        command: [root.script, "--dir", root.dir, "watch"]
        stdout: SplitParser { onRead: name => { refreshSoon.restart(); root.changedOnDisk(name); } }
    }
    signal changedOnDisk(string file)
    Timer { id: refreshSoon; interval: 250; onTriggered: root.refresh() }
    onReadyChanged: if (ready) refresh()

    // ── search (titles and text) ──
    property string query: ""
    property var hits: []
    onQueryChanged: { if (query.trim() === "") hits = []; else searchSoon.restart(); }
    Timer { id: searchSoon; interval: 140; onTriggered: { searchProc.command = [root.script, "--dir", root.dir, "search", root.query]; searchProc.running = true; } }
    Process {
        id: searchProc
        stdout: StdioCollector { onStreamFinished: { try { root.hits = JSON.parse(text); } catch (e) {} } }
    }

    // ── create · rename · trash ──
    signal created(string file)
    signal renamed(string from, string to)
    function create(title) { newProc.command = [script, "--dir", dir, "new", title ?? ""]; newProc.running = true; }
    Process {
        id: newProc
        stdout: StdioCollector { onStreamFinished: { const f = text.trim(); if (f) { root.refresh(); root.created(f); } } }
    }
    function rename(file, title) {
        if (!title.trim()) return;
        renameProc.from = file;
        renameProc.command = [script, "--dir", dir, "rename", file, title.trim()];
        renameProc.running = true;
    }
    Process {
        id: renameProc
        property string from: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const to = text.trim();
                if (!to) return;
                if (root.isPinned(renameProc.from)) root.cfg.pinned = root.cfg.pinned.map(f => f === renameProc.from ? to : f);
                root.refresh();
                root.renamed(renameProc.from, to);
            }
        }
    }
    property string lastTrashed: ""
    function trash(file) {
        lastTrashed = file;
        if (isPinned(file)) togglePin(file);
        Quickshell.execDetached([script, "--dir", dir, "trash", file]);
        refreshSoon.restart();
    }
    // Trash: list and put back
    property var trashed: []
    function refreshTrash() { trashProc.command = [script, "--dir", dir, "restore"]; trashProc.running = true; }
    Process { id: trashProc; stdout: StdioCollector { onStreamFinished: { try { root.trashed = JSON.parse(text); } catch (e) {} } } }
    function restore(name) { restoreProc.command = [script, "--dir", dir, "restore", name]; restoreProc.running = true; }
    Process {
        id: restoreProc
        stdout: StdioCollector { onStreamFinished: { const f = text.trim(); root.refresh(); root.refreshTrash(); if (f) root.created(f); } }
    }

    // ═════ phone sync (Syncthing) ═════
    property var sync: ({})
    readonly property bool syncOn: !!sync.running && !!sync.folder
    readonly property var phones: (sync.devices ?? []).filter(d => d.shared)
    readonly property bool phoneConnected: phones.some(d => d.connected)
    property bool syncBusy: false
    property string syncError: ""
    property bool watchingSync: false     // a view showing sync state is open
    function refreshSync() { if (!syncProc.running) syncProc.running = true; }
    Process {
        id: syncProc
        command: [root.syncScript, "--dir", root.dir, "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.sync = JSON.parse(text); } catch (e) {} } }
    }
    Timer { interval: root.watchingSync ? 3000 : 30000; repeat: true; triggeredOnStart: true; running: root.app || root.watchingSync; onTriggered: root.refreshSync() }
    function syncAction(args) {
        syncBusy = true; syncError = "";
        actionProc.command = [syncScript, "--dir", dir].concat(args);
        actionProc.running = true;
    }
    Process {
        id: actionProc
        stdout: StdioCollector {
            onStreamFinished: {
                root.syncBusy = false;
                try { const r = JSON.parse(text); if (r.ok === false) root.syncError = r.error ?? "Didn't work"; } catch (e) {}
                root.refreshSync();
                root.makeQr();
            }
        }
        onExited: root.syncBusy = false
    }
    function setupSync() { syncAction(["setup"]); }
    function acceptPhone(id, name) { syncAction(["accept", id, name || "Phone"]); }
    function forgetDevice(id) { syncAction(["forget", id]); }
    function stopSync() { syncAction(["stop"]); }
    // This computer's ID as a QR code (the phone scans it)
    readonly property string qrPath: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lumen-notes-sync-qr.png"
    property int qrVersion: 0
    function makeQr() { if (sync.running && !qrProc.running) qrProc.running = true; }
    onSyncChanged: if (sync.running && qrVersion === 0) makeQr()
    Process { id: qrProc; command: [root.syncScript, "qr", root.qrPath]; onExited: code => { if (code === 0) root.qrVersion++; } }
}
