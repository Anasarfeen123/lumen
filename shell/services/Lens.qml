pragma Singleton
// Circle to search (Super+Z, "circle to search" in Halo, the island's Halo
// card). The focused screen freezes; draw round anything — or click a window,
// or drag a box — and a sheet rises with what you can do with it:
//   Ask Halo (type a question, or just Enter: "what is this?") · Copy text ·
//   Translate · Search the web · Google Lens · Copy image · Save · Send to phone
// The text is read on this computer (tesseract). Nothing leaves it unless you
// press Search / Google Lens, or Halo's model is a cloud one and you ask.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root
    readonly property string script: Theme.lumenRoot + "/scripts/lens.sh"
    readonly property string dir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lumen-lens"

    property bool open: false
    property string screen: ""          // the monitor it froze
    property string shot: ""            // the frozen screen (png)
    property real stamp: 0
    // the circled piece
    property rect sel: Qt.rect(0, 0, 0, 0)
    readonly property bool picked: sel.width > 0
    property string crop: ""
    property string cropReady: ""       // the same, once the file is written (for the thumbnail)
    property string text: ""            // what tesseract read
    property bool reading: false
    property bool asked: false          // Halo is answering in the sheet

    function start() {
        if (open || shooter.running) return;
        cleanup.stop();
        // Panels over the screen first slide away, so they aren't in the picture
        if (Ai.open || Overview.open || Sidebar.open) { Ai.open = false; Overview.open = false; Sidebar.open = false; later.restart(); return; }
        Ai.prepare();
        const mon = Hyprland.focusedMonitor?.name ?? Quickshell.screens[0]?.name ?? "";
        stamp = Date.now();
        screen = mon;
        shooter.out = dir + "/screen-" + stamp + ".png";
        shooter.command = [script, "shot", mon, shooter.out];
        shooter.running = true;
    }
    Timer { id: later; interval: 320; onTriggered: root.start() }
    Process {
        id: shooter
        property string out: ""
        onExited: code => {
            if (code !== 0) { Island.system("error", "Couldn't capture the screen", ""); return; }
            root.shot = shooter.out;
            root.reset();
            root.open = true;
        }
    }
    function reset() { sel = Qt.rect(0, 0, 0, 0); crop = ""; cropReady = ""; text = ""; reading = false; asked = false; }
    function close() {
        if (!open) return;
        open = false;
        cleanup.restart();                  // after the overlay has faded away
    }
    Timer {
        id: cleanup
        interval: 360
        onTriggered: { if (root.open) return; Quickshell.execDetached([root.script, "clean"]); root.shot = ""; root.reset(); }
    }

    // r: the selection in screen pixels of the frozen image
    function pick(r) {
        sel = r;
        crop = dir + "/piece-" + Date.now() + ".png";
        cropper.command = [script, "crop", shot, String(Math.round(r.x)), String(Math.round(r.y)), String(Math.round(r.width)), String(Math.round(r.height)), crop];
        cropper.running = true;
        text = "";
        reading = true;
    }
    Process {
        id: cropper
        onExited: code => {
            if (code !== 0) { root.reading = false; return; }
            root.cropReady = root.crop;
            ocr.command = [root.script, "ocr", root.crop];
            ocr.running = true;
        }
    }
    Process {
        id: ocr
        stdout: StdioCollector { onStreamFinished: { root.text = text.trim(); root.reading = false; } }
        onExited: code => { if (code !== 0) root.reading = false; }
    }

    // ── what you can do with it ──
    function ask(question) {
        if (!crop) return;
        asked = true;
        // A copy Halo can keep after the overlay is gone
        keeper.question = question;
        keeper.file = Ai.runDir + "/lens-" + Date.now() + ".png";
        keeper.command = ["sh", "-c", 'mkdir -p "$(dirname "$2")" && chmod 700 "$(dirname "$2")" && cp "$1" "$2"', "sh", crop, keeper.file];
        keeper.running = true;
    }
    Process {
        id: keeper
        property string question: ""
        property string file: ""
        onExited: code => { if (code === 0) Ai.askImage(keeper.question, keeper.file, root.text); }
    }
    function copyText() { if (text) { Ai.copy(text); Island.system("content_copy", "Copied the text", text.split(/\s+/).length + " words"); close(); } }
    function translate() { ask("Translate this into English. Reply with only the translation" + (text ? "." : " of the text in the image.")); }
    function webSearch() {
        if (!text) return;
        Qt.openUrlExternally(Search.webSearchUrl.replace("%s", encodeURIComponent(text.replace(/\s+/g, " ").slice(0, 300))));
        close();
    }
    function google() { if (crop) { Quickshell.execDetached([script, "google", crop]); Island.system("image_search", "Paste it into Google Lens", "The picture is on your clipboard — Ctrl+V"); close(); } }
    function copyImage() { if (crop) { Quickshell.execDetached([script, "copy-image", crop]); Island.system("content_copy", "Copied the picture", ""); close(); } }
    function save() { if (crop) { saver.command = [script, "save", crop]; saver.running = true; } }
    Process {
        id: saver
        stdout: StdioCollector { onStreamFinished: { const f = text.trim(); if (f) Island.push({ kind: "system", key: "lens-save", priority: Island.priority.system, duration: 3500, force: true, queueable: true, data: { icon: "image", title: "Saved", detail: f.replace(/.*\//, ""), path: f } }); root.close(); } }
    }
    function toPhone() { if (crop && Link.phone) { const keep = Quickshell.env("HOME") + "/Pictures/Screenshots/Lens_" + Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss") + ".png";
                                                    Quickshell.execDetached(["sh", "-c", 'mkdir -p "$(dirname "$2")" && cp "$1" "$2"', "sh", crop, keep]);
                                                    Qt.callLater(() => Link.sendFiles([keep])); close(); } }

    GlobalShortcut { appid: "lumen"; name: "lens"; description: "Circle to search"; onPressed: root.open ? root.close() : root.start() }
    IpcHandler {
        target: "lens"
        function start(): void { root.start(); }
        function close(): void { root.close(); }
        function ask(q: string): void { root.ask(q); }
        function state(): string { return JSON.stringify({ open: root.open, sel: [root.sel.x, root.sel.y, root.sel.width, root.sel.height], text: root.text, crop: root.crop }); }
        // Dev only (LUMEN_DEV): pick a rectangle as if circled
        function pick(x: int, y: int, w: int, h: int): void { if (Quickshell.env("LUMEN_DEV") === "1") root.pick(Qt.rect(x, y, w, h)); }
    }
}
