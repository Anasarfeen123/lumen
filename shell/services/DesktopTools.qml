pragma Singleton
// State and local actions for the Tools panel. Modules only render/call this.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    property bool open: false
    property string page: "screenshots"
    property string origin: "center"
    onOpenChanged: if (!open) Audio.micTesting = false
    onPageChanged: if (page !== "meeting") Audio.micTesting = false
    property string message: ""
    readonly property string home: Quickshell.env("HOME")
    readonly property string helper: Theme.lumenRoot + "/scripts/desktop-tools.py"
    readonly property var pages: [
        { id: "screenshots", name: "Screenshots", icon: "screenshot_monitor", hint: "Capture, annotate and extract text" },
        { id: "folders", name: "Folders", icon: "folder_open", hint: "Your folders, one glance away" },
        { id: "operations", name: "File queue", icon: "swap_horiz", hint: "Background jobs, with real progress" },
        { id: "storage", name: "Storage", icon: "hard_drive", hint: "See where your space goes" },
        { id: "colours", name: "Colours", icon: "palette", hint: "Pick, keep and copy colours" },
        { id: "meeting", name: "Meeting", icon: "video_call", hint: "Your call controls, together" }
    ]
    readonly property var currentPage: pages.find(p => p.id === page) ?? pages[0]
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || root.home + "/.local/state") + (Quickshell.env("LUMEN_NESTED") ? "/lumen/tools-test.json" : "/lumen/tools.json")
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }
        JsonAdapter {
            id: prefs
            property var folders: []
            property var colours: []
        }
    }
    readonly property var pinnedFolders: prefs.folders
    readonly property var colours: prefs.colours
    property var defaultFolders: []
    property var folder: ({ path: home, parent: home, entries: [] })
    property string folderWanted: home
    property string folderFilter: ""
    property bool showHidden: false
    readonly property var folderEntries: (folder.entries ?? []).filter(e => (showHidden || !e.name.startsWith(".")) && e.name.toLowerCase().includes(folderFilter.toLowerCase()))
    property var shots: []
    property var selectedShot: null
    property string shotsPath: ""
    readonly property bool browsing: folderRequest.busy
    readonly property bool loadingShots: shotsRequest.busy
    readonly property bool imageBusy: actionRequest.busy
    readonly property bool picking: colourRequest.busy
    property var storage: ({ entries: [] })
    property string storagePath: home
    property string scanLabel: ""
    property bool scanFinished: false
    readonly property bool scanning: storageProc.busy
    readonly property bool cancellingScan: storageProc.stopping

    function show(which, source) {
        if (Lock.locked) return;
        page = pages.some(p => p.id === which) ? which : "screenshots";
        origin = source ?? "center";
        message = "";
        Overview.hide(); Sidebar.hide(); Planner.open = false; DropZone.hide(); Ai.open = false;
        open = true;
        if (!defaultFolders.length) defaultsRequest.start(["folders"]);
        refreshVisible();
    }
    function hide() { open = false; }
    function refreshVisible() {
        if (!open) return;
        if (page === "screenshots") refreshShots();
        if (page === "folders") browse(folderWanted);
    }
    function refreshShots() { shotsRequest.start(["screenshots"]); }
    function prepareFolders() {
        if (!defaultFolders.length) defaultsRequest.start(["folders"]);
        browse(folderWanted);
    }
    function inspectScreenshot(value) {
        selectedShot = { path: value, uri: "file://" + value.split("/").map(encodeURIComponent).join("/"), name: value.replace(/^.*\//, "") };
        show("screenshots");
    }
    ToolsRequest {
        id: defaultsRequest; helper: root.helper
        onResult: value => { if (!value.error) root.defaultFolders = value; }
    }
    ToolsRequest {
        id: shotsRequest; helper: root.helper
        onResult: value => {
            if (value.error) { root.message = value.error; return; }
            root.shots = value.entries; root.shotsPath = value.path;
            root.selectedShot = value.entries.find(e => e.path === root.selectedShot?.path) ?? value.entries[0] ?? null;
        }
    }
    function browse(value) {
        message = ""; folderWanted = value;
        folderRequest.start(["browse", value]);
    }
    ToolsRequest {
        id: folderRequest; helper: root.helper
        onResult: value => {
            if (value.error) { root.message = value.error; root.folderWanted = root.folder.path; return; }
            root.folder = value; root.folderWanted = value.path; root.folderFilter = "";
        }
    }
    function pinFolder() {
        const p = folder.path;
        if (p && !pinnedFolders.some(f => f.path === p)) prefs.folders = pinnedFolders.concat([{ path: p, name: p.replace(/^.*\//, "") || "/" }]).slice(-20);
    }
    function unpinFolder(value) { prefs.folders = pinnedFolders.filter(f => f.path !== value); }
    function openPath(value) { Quickshell.execDetached(["xdg-open", value]); }
    function imageAction(kind) {
        if (selectedShot && !imageBusy) actionRequest.start(["action", kind, selectedShot.path]);
    }
    ToolsRequest {
        id: actionRequest; helper: root.helper
        onResult: value => {
            root.message = value.error ?? value.message ?? "";
            if (value.path) root.selectedShot = { path: value.path, uri: "file://" + value.path.split("/").map(encodeURIComponent).join("/"), name: value.path.replace(/^.*\//, "") };
            root.refreshShots();
        }
    }
    function capture(kind) { hide(); captureTimer.kind = kind; captureTimer.restart(); }
    Timer {
        id: captureTimer; property string kind: "region"; interval: 450
        onTriggered: Quickshell.execDetached([Theme.lumenRoot + "/scripts/screenshot.sh", kind])
    }
    function pickColour() { if (picking) return; hide(); pickTimer.restart(); }
    Timer { id: pickTimer; interval: 450; onTriggered: colourRequest.start(["pick-colour"]) }
    ToolsRequest {
        id: colourRequest; helper: root.helper
        onResult: value => {
            if (value.error) { root.show("colours"); root.message = value.error; }
            else if (value.colour) { root.addColour(value.colour); root.copyText(value.colour); root.show("colours"); }
        }
    }
    function addColour(value) {
        const hex = value.trim().toUpperCase();
        if (!/^#[0-9A-F]{6}$/.test(hex)) { message = "Use a six-digit HEX colour, such as #52D1E9"; return; }
        prefs.colours = [{ hex, name: colours.find(c => c.hex === hex)?.name ?? "", at: Date.now() }].concat(colours.filter(c => c.hex !== hex)).slice(0, 60);
        message = "Colour saved";
    }
    function renameColour(hex, name) { prefs.colours = colours.map(c => c.hex === hex ? Object.assign({}, c, { name: name.trim().slice(0, 60) }) : c); }
    function removeColour(hex) { prefs.colours = colours.filter(c => c.hex !== hex); }
    function rgb(hex) { return "rgb(" + [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16)).join(", ") + ")"; }
    function hsl(hex) {
        const a = [1, 3, 5].map(i => parseInt(hex.slice(i, i + 2), 16) / 255);
        const max = Math.max(...a), min = Math.min(...a), d = max - min, l = (max + min) / 2;
        let h = 0;
        if (d) h = max === a[0] ? ((a[1] - a[2]) / d + 6) % 6 : max === a[1] ? (a[2] - a[0]) / d + 2 : (a[0] - a[1]) / d + 4;
        const s = d === 0 ? 0 : d / (1 - Math.abs(2 * l - 1));
        return "hsl(" + Math.round(h * 60) + ", " + Math.round(s * 100) + "%, " + Math.round(l * 100) + "%)";
    }
    function copyText(value) { textCopy.start(["copy-text", value]); }
    ToolsRequest {
        id: textCopy; helper: root.helper
        onResult: value => root.message = value.error ?? value.message ?? ""
    }
    function scan(value) {
        if (scanning) return;
        storagePath = value; scanLabel = "Preparing scan…"; scanFinished = false; message = "";
        storageProc.stopping = false;
        storageProc.start(["python3", helper, "storage", value]);
    }
    function cancelScan() { if (scanning) { storageProc.stopping = true; storageProc.signal(15); } }
    ToolsStream {
        id: storageProc
        property bool stopping: false
        onEvent: v => {
                if (v.type === "scanning") root.scanLabel = "Scanning · " + v.name;
                if (v.type === "storage") { root.storage = v; root.storagePath = v.path; root.scanFinished = true; }
                if (v.type === "error") root.message = v.error;
                if (v.type === "cancelled") root.message = "Scan stopped; previous results kept";
        }
        onFinished: code => { if (code !== 0 && !stopping && !root.message) root.message = "Storage scan could not finish"; }
    }
    function queue(kind, paths, destination) {
        FileOperations.enqueue(kind, paths, destination);
        page = "operations"; open = true;
    }
    function size(bytes) {
        if (bytes < 1024) return bytes + " B";
        const units = ["KiB", "MiB", "GiB", "TiB"], i = Math.min(3, Math.floor(Math.log(bytes) / Math.log(1024)) - 1);
        return (bytes / Math.pow(1024, i + 1)).toFixed(i < 1 ? 0 : 1) + " " + units[i];
    }
    function returnToCall() {
        if (Meeting.meetingWindow) { callLater.address = Meeting.meetingWindow.lastIpcObject?.address || ("0x" + Meeting.meetingWindow.address); hide(); callLater.restart(); }
        else message = "No meeting window found";
    }
    Timer { id: callLater; property string address: ""; interval: Theme.motion.normal; onTriggered: if (!Lock.locked && address) Hypr.focusWindow(address) }
    function meetingNotes() { Meeting.notes(Meeting.appName, Meeting.since ? Math.max(1, Math.round((Date.now() - Meeting.since) / 60000)) : 0); }
    function soundSettings() { hide(); SettingsState.launch("sound"); }
    function cameraPreview() { hide(); Quickshell.execDetached([Theme.lumenRoot + "/scripts/mirror.sh"]); }
    Connections {
        target: FileOperations
        function onSettled(job, result) {
            if (job?.kind === "move") {
                const names = (result.completed ?? []).map(p => p.replace(/^.*\//, ""));
                for (const p of job.paths) if (names.includes(p.replace(/^.*\//, ""))) DropZone.unshelve(p);
            }
            Qt.callLater(root.refreshVisible);
        }
    }
    Connections { target: Lock; function onLockedChanged() { if (Lock.locked) root.hide(); } }
    IpcHandler {
        target: "tools"
        function open(page: string): void { root.show(page); }
        function close(): void { root.hide(); }
        function colour(): void { root.pickColour(); }
        function screenshot(path: string): void { root.inspectScreenshot(path); }
    }
}
