pragma Singleton
// Circle to Search: generation-tagged crops, verified local actions and one
// private directory per capture. A failed action stays open with its error.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root
    readonly property string helper: Theme.lumenRoot + "/scripts/lens.py"
    readonly property string dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lumen-lens"
    property bool open: false
    property string screen: ""
    property string shot: ""
    property real stamp: 0
    property string session: ""
    property int serial: 0
    property int version: 0
    property bool captureCancelled: false
    property var retired: []
    property rect sel: Qt.rect(0, 0, 0, 0)
    readonly property bool picked: sel.width > 0 && sel.height > 0
    property string crop: ""
    property string cropReady: ""
    readonly property bool ready: open && cropReady !== "" && cropReady === crop
    property string text: ""
    property string message: ""
    property bool reading: false
    property bool asked: false
    readonly property bool busy: action.busy || keeper.busy
    readonly property bool cropping: cropper.busy
    property bool autoTranslate: false

    function start() {
        if (Lock.locked || open || shooter.busy || later.running) return;
        if (Ai.open || Overview.open || Sidebar.open || Planner.open || DesktopTools.open || DropZone.open) {
            Ai.open = false; Overview.hide(); Sidebar.hide(); Planner.open = false; DesktopTools.hide(); DropZone.hide();
            later.restart(); return;
        }
        Ai.prepare();
        stamp = Date.now();
        session = dir + "/session-" + stamp + "-" + (++serial);
        captureCancelled = false;
        screen = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
        reset();
        shooter.start(["shot", screen, session + "/screen.png"], session);
    }
    Timer { id: later; interval: 450; onTriggered: root.start() }
    ToolsRequest {
        id: shooter; helper: root.helper
        onAnswered: (value, token) => {
            if (token !== root.session || root.captureCancelled || Lock.locked) { root.retire(token); return; }
            if (value.error) { root.message = value.error; Island.system("error", "Couldn't capture the screen", value.error, "error"); root.retire(token); return; }
            root.shot = value.path; root.open = true;
        }
    }
    function reset() {
        version++;
        sel = Qt.rect(0, 0, 0, 0); crop = ""; cropReady = ""; text = "";
        message = ""; reading = false; asked = false;
    }
    function retire(value) {
        if (value && !retired.includes(value)) retired = retired.concat([value]);
        cleanup.restart();
    }
    function close() {
        later.stop(); autoTranslate = false; captureCancelled = true;
        open = false; retire(session);
    }
    Timer {
        id: cleanup; interval: 360
        onTriggered: {
            if (root.busy || shooter.busy || cropper.busy || ocr.busy || cleaner.busy) { restart(); return; }
            if (!root.retired.length) return;
            const next = root.retired[0]; root.retired = root.retired.slice(1);
            cleaner.start(["clean", next]);
            if (!root.open) { root.shot = ""; root.reset(); }
            if (root.retired.length) restart();
        }
    }
    ToolsRequest { id: cleaner; helper: root.helper }
    function current(token) { return open && token?.session === session && token?.version === version; }
    function pick(r) {
        if (!open || !shot) return;
        version++; sel = r; cropReady = ""; text = ""; message = ""; asked = false;
        crop = session + "/piece-" + version + ".png";
        reading = true;
        cropper.start(["crop", shot, String(r.x), String(r.y), String(r.width), String(r.height), crop], { session, version });
    }
    ToolsRequest {
        id: cropper; helper: root.helper
        onAnswered: (value, token) => {
            if (!root.current(token)) return;
            if (value.error) { root.message = value.error; root.reading = false; return; }
            root.cropReady = value.path;
            ocr.start(["ocr", value.path], token);
        }
    }
    ToolsRequest {
        id: ocr; helper: root.helper
        onAnswered: (value, token) => {
            if (!root.current(token)) return;
            root.text = value.text ?? ""; root.message = value.error ?? ""; root.reading = false;
        }
    }
    function requireImage() {
        if (!ready) { message = "Wait for the selection to finish, then try again"; return false; }
        return !busy;
    }
    function ask(question) {
        if (!requireImage()) return;
        if (!Ai.configured) { message = "Choose a model in Settings → Halo first"; return; }
        if (reading && !Ai.vision) { message = "Still reading the selection; try again in a moment"; return; }
        message = "";
        const file = Ai.runDir + "/lens-" + Date.now() + "-" + version + ".png";
        keeper.start(["keep", cropReady, file], { session, version, question, text });
    }
    ToolsRequest {
        id: keeper; helper: root.helper
        onAnswered: (value, token) => {
            if (!root.current(token)) return;
            if (value.error) { root.message = value.error; return; }
            root.asked = true;
            Ai.askImage(token.question, value.path, token.text);
        }
    }
    function startTranslate() { autoTranslate = true; start(); }
    onReadingChanged: if (!reading && autoTranslate && ready) { autoTranslate = false; translate(); }
    function translate() { ask("Translate this into English. Reply with only the translation."); }
    function perform(kind) {
        if (!requireImage()) return;
        if (kind === "text" && !text) { message = reading ? "Still reading the selection…" : "No text found in this selection"; return; }
        if (kind === "phone" && !Link.connected) { message = "Connect your phone in Lumen Link first"; return; }
        message = "";
        const command = kind === "image" || kind === "google" ? ["copy-image", cropReady] : kind === "text" ? ["copy-text", text] : ["save", cropReady];
        action.start(command, { session, version, kind });
    }
    ToolsRequest {
        id: action; helper: root.helper
        onAnswered: (value, token) => {
            if (!root.current(token)) return;
            if (value.error) { root.message = value.error; return; }
            if (token.kind === "google") {
                root.close(); googleLater.restart();
                Island.system("image_search", "Picture copied for Google Lens", "Paste it into Google Lens with Ctrl+V");
            } else if (token.kind === "phone") {
                Link.sendFiles([value.path]); root.close();
            } else if (token.kind === "save") {
                Island.push({ kind: "system", key: "lens-save", priority: Island.priority.system, duration: 3500, force: true, queueable: true,
                              data: { icon: "image", title: "Saved", detail: value.path.replace(/^.*\//, ""), path: value.path } });
                root.close();
            } else { Island.system("content_copy", value.message, ""); root.close(); }
        }
    }
    Timer { id: googleLater; interval: 400; onTriggered: Qt.openUrlExternally("https://lens.google/") }
    function copyText() { perform("text"); }
    function copyImage() { perform("image"); }
    function google() { perform("google"); }
    function save() { perform("save"); }
    function toPhone() { perform("phone"); }
    function webSearch() {
        if (!text || reading || busy) return;
        const url = Search.webSearchUrl.replace("%s", encodeURIComponent(text.replace(/\s+/g, " ").slice(0, 300)));
        close(); webLater.url = url; webLater.restart();
    }
    Timer { id: webLater; property string url: ""; interval: 400; onTriggered: Qt.openUrlExternally(url) }
    Connections { target: Lock; function onLockedChanged() { if (Lock.locked) root.close(); } }
    GlobalShortcut { appid: "lumen"; name: "lens"; description: "Circle to search"; onPressed: root.open || shooter.busy || later.running ? root.close() : root.start() }
    IpcHandler {
        target: "lens"
        function start(): void { root.start(); }
        function close(): void { root.close(); }
        function ask(q: string): void { root.ask(q); }
        function state(): string { return JSON.stringify({ open: root.open, ready: root.ready, busy: root.busy, reading: root.reading, sel: [root.sel.x, root.sel.y, root.sel.width, root.sel.height], text: root.text, crop: root.cropReady, error: root.message }); }
        function pick(x: int, y: int, w: int, h: int): void { if (Quickshell.env("LUMEN_DEV") === "1") root.pick(Qt.rect(x, y, w, h)); }
    }
}
