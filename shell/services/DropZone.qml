pragma Singleton
// Drop Zone — drag files to the right edge of the screen and a shelf of
// actions slides in: Send to phone · Copy · Compress · Keep on shelf ·
// Open with… · Move to…. scripts/dropzone.sh does the work; the island
// confirms. The shelf (files you parked) stays at the edge as a small tab
// until you drag them out or clear it. Nothing is ever uploaded.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root
    property bool open: false            // the shelf is showing
    property bool dragging: false        // opened by a drag (vs. by hand)
    property string where: ""            // the monitor a drag arrived on
    property bool testHold: false        // dev: a simulated drag stays open until released
    property var hovering: []            // paths being dragged over the zone
    property var shelf: []               // paths parked on the shelf
    property var phone: null             // { id, name } — first reachable phone
    property var apps: []                // apps for the hovered/shelved file type
    readonly property string script: Theme.lumenRoot + "/scripts/dropzone.sh"

    // The files an action applies to: what's being dragged, else the shelf
    readonly property var subject: hovering.length ? hovering : shelf

    function pathsOf(urls) {
        const out = [];
        for (const u of urls ?? []) {
            const s = String(u);
            if (s.startsWith("file://")) out.push(decodeURIComponent(s.slice(7)));
        }
        return out;
    }
    function describe(paths) {
        if (!paths.length) return "";
        const name = paths[0].replace(/\/+$/, "").replace(/.*\//, "");
        return paths.length === 1 ? name : paths.length + " items · " + name + "…";
    }

    // ── showing ──
    function dragEntered(urls) {
        const p = pathsOf(urls);
        dragging = true;
        hovering = p;
        if (!where) where = Hyprland.focusedMonitor?.name ?? "";
        if (!open) { open = true; probe(p[0] ?? ""); }
    }
    function dragDone() { dragging = false; hovering = []; open = false; where = ""; }
    function show() { dragging = false; hovering = []; open = true; probe(shelf[0] ?? ""); }
    function hide() { dragging = false; hovering = []; open = false; }
    function toggle() { if (open) hide(); else show(); }

    // Phone and "open with" apps, looked up each time the shelf opens
    function probe(file) {
        phoneProc.running = true;
        apps = [];
        if (file) { appsProc.command = [script, "apps", file]; appsProc.running = true; }
    }
    Process {
        id: phoneProc
        command: [root.script, "phone"]
        stdout: StdioCollector { onStreamFinished: { try { root.phone = JSON.parse(text); } catch (e) { root.phone = null; } } }
    }
    Process {
        id: appsProc
        stdout: StdioCollector { onStreamFinished: { try { root.apps = JSON.parse(text); } catch (e) { root.apps = []; } } }
    }

    // ── actions ── (paths: explicit, else the subject)
    function run(action, paths, arg) {
        paths = (paths && paths.length) ? paths : subject;
        if (!paths.length) return;
        const what = describe(paths), n = paths.length;
        const noun = n === 1 ? what : n + " items";
        switch (action) {
        case "copy":
            Quickshell.execDetached([script, "copy"].concat(paths));
            Island.system("content_copy", "Copied " + noun, "Paste into a folder or a chat");
            break;
        case "compress":
            Island.progress("dropzone-zip", "folder_zip", "Compressing " + noun, -1, "");
            job.start(["compress"].concat(paths), out => Island.push({ kind: "system", key: "progress:dropzone-zip", priority: Island.priority.system, duration: 3500, queueable: true, force: true,
                data: { icon: out ? "folder_zip" : "error", title: out ? "Compressed " + noun : "Couldn't compress " + noun, detail: out ? out.replace(/.*\//, "") : "", tone: out ? "success" : "error" } }));
            break;
        case "send":
            if (!phone) return;
            Island.progress("dropzone-send", "send_to_mobile", "Sending " + noun, -1, phone.name);
            job.start(["send", phone.id].concat(paths), out => Island.push({ kind: "system", key: "progress:dropzone-send", priority: Island.priority.system, duration: 3500, queueable: true, force: true,
                data: { icon: out ? "mobile_check" : "error", title: out ? "Sent " + noun : "Couldn't send " + noun, detail: phone?.name ?? "", tone: out ? "success" : "error" } }));
            break;
        case "move":
            job.start(["move", arg].concat(paths), out => {
                const [moved, skipped] = (out || "0 0").split(" ").map(Number);
                const place = arg.charAt(0).toUpperCase() + arg.slice(1);
                Island.system(moved ? "drive_file_move" : "error", moved ? "Moved " + (moved === 1 && n === 1 ? what : moved + " items") + " to " + place : "Nothing moved",
                              skipped ? skipped + " already there, left alone" : "", moved ? "normal" : "warning");
                if (moved) shelf = shelf.filter(p => !paths.includes(p));
            });
            break;
        case "open":
            Quickshell.execDetached([script, "open", arg].concat(paths));
            break;
        case "shelve":
            shelf = shelf.concat(paths.filter(p => !shelf.includes(p)));
            Island.system("inventory_2", "On the shelf", noun + " · drag it out when you need it");
            break;
        }
        if (action !== "shelve") hovering = [];
        if (dragging) { dragging = false; open = false; }
    }
    function unshelve(path) { shelf = shelf.filter(p => p !== path); if (!shelf.length && !dragging) open = false; }
    function clearShelf() { shelf = []; if (!dragging) open = false; }

    // One background job at a time; its last stdout line goes to the callback ("" on failure).
    // The exit and the end of output can arrive in either order: finish when both have.
    Process {
        id: job
        property var done: null
        property var queue: []
        property int code: -1
        property bool exited: false
        property bool streamed: false
        function start(args, cb) {
            if (running || done) { queue = queue.concat([{ args, cb }]); return; }
            done = cb; exited = false; streamed = false; code = -1;
            command = [root.script].concat(args);
            running = true;
        }
        function finish() {
            if (!exited || !streamed) return;
            const cb = done; done = null;
            if (cb) cb(code === 0 ? jobOut.text.trim().split("\n").pop() : "");
            if (queue.length) { const q = queue[0]; queue = queue.slice(1); start(q.args, q.cb); }
        }
        stdout: StdioCollector { id: jobOut; onStreamFinished: { job.streamed = true; job.finish(); } }
        onExited: c => { code = c; exited = true; finish(); }
    }

    IpcHandler {
        target: "dropzone"
        function open(): void { root.show(); }
        function close(): void { root.hide(); }
        function toggle(): void { root.toggle(); }
    }
    // Dev only: pretend a drag arrived, or drop files on a target
    IpcHandler {
        target: "dropzoneTest"
        enabled: Quickshell.env("LUMEN_DEV") === "1"
        function hover(path: string): void { root.testHold = true; root.dragEntered(path.split("|").map(p => "file://" + p)); }
        function release(): void { root.testHold = false; root.dragDone(); }
        function drop(path: string): void { root.shelf = root.shelf.concat(path.split("|")); root.show(); }
        function act(action: string, arg: string): void { root.run(action, root.subject, arg); }
        function state(): string { return JSON.stringify({ open: root.open, dragging: root.dragging, hovering: root.hovering, shelf: root.shelf, phone: root.phone, apps: root.apps.map(a => a.id) }); }
    }
}
