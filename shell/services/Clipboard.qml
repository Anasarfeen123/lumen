pragma Singleton

// Clipboard history (cliphist) plus pins, for the overview's clipboard mode
// (Super+V).
//
//   history   newest first; image entries get real thumbnails (decoded into
//             $XDG_RUNTIME_DIR/lumen-clip, which is RAM and private to you)
//   pins      Alt+P pins / unpins; pinned items live in Lumen's state (text,
//             or a PNG copy), so they survive cliphist's own limits
//   use       Enter pastes into the app you were in · Ctrl+Enter pastes as
//             plain text · Alt+Enter only copies · Shift+Del removes
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    property var entries: []     // { id, text, isImage, thumb }
    readonly property var pins: Persist.data.clipPins ?? []
    readonly property string thumbDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lumen-clip"
    readonly property string pinDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/lumen/clip-pins"
    property int thumbVersion: 0

    function refresh() { proc.running = false; proc.running = true; }

    // ── use ──
    // mode: "paste" (default) | "plain" | "copy"
    function use(id, mode) {
        const n = parseInt(id);
        if (mode === "plain")
            Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | sed -e "s/<[^>]*>//g" | wl-copy --type text/plain', "sh", String(n)]);
        else
            Quickshell.execDetached(["sh", "-c", 'cliphist decode "$1" | wl-copy', "sh", String(n)]);
        if (mode !== "copy") pasteSoon();
    }
    function usePin(pin, mode) {
        if (pin.kind === "image") Quickshell.execDetached(["sh", "-c", 'wl-copy --type image/png < "$1"', "sh", pin.file]);
        else if (mode === "plain") Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | sed -e "s/<[^>]*>//g" | wl-copy --type text/plain', "sh", pin.text]);
        else Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", pin.text]);
        if (mode !== "copy") pasteSoon();
    }

    // Paste = send the app its paste shortcut once the overview has closed
    // and focus is back on it (terminals use Ctrl+Shift+V).
    readonly property var terminals: ["kitty", "foot", "alacritty", "org.wezfurlong.wezterm", "com.mitchellh.ghostty", "konsole", "org.kde.konsole", "xterm", "lumen-dropterm"]
    function pasteSoon() { pasteTimer.restart(); }
    Timer {
        id: pasteTimer
        interval: 260
        onTriggered: {
            const cls = (Hyprland.activeToplevel?.lastIpcObject?.class ?? "").toLowerCase();
            const mods = root.terminals.includes(cls) ? "CTRL SHIFT" : "CTRL";
            Hyprland.dispatch(`hl.dsp.send_shortcut({ mods = "${mods}", key = "V" })`);
        }
    }

    function remove(id) {
        Quickshell.execDetached(["sh", "-c", 'cliphist list | grep -m1 "^$1	" | cliphist delete', "sh", String(parseInt(id))]);
        entries = entries.filter(e => e.id !== id);
    }

    // ── pins ──
    function isPinnedText(text) { return pins.some(p => p.kind === "text" && p.text === text); }
    function pin(entry) {
        if (entry.isImage) {
            const file = pinDir + "/" + Date.now() + ".png";
            pinProc.command = ["sh", "-c", 'mkdir -p "$(dirname "$2")" && cliphist decode "$1" > "$2" && echo ok', "sh", String(parseInt(entry.id)), file];
            pinProc.pending = { kind: "image", text: "", file };
        } else {
            pinProc.command = ["cliphist", "decode", String(parseInt(entry.id))];
            pinProc.pending = { kind: "text" };
        }
        pinProc.running = true;
    }
    function unpin(index) {
        const p = pins[index];
        if (p?.kind === "image") Quickshell.execDetached(["rm", "-f", "--", p.file]);
        Persist.data.clipPins = pins.filter((_, i) => i !== index);
    }
    Process {
        id: pinProc
        property var pending: null
        stdout: StdioCollector {
            onStreamFinished: {
                const p = pinProc.pending;
                if (!p) return;
                if (p.kind === "text") { if (text !== "" && !root.isPinnedText(text)) Persist.data.clipPins = [{ kind: "text", text, file: "" }].concat(root.pins); }
                else if (text.trim() === "ok") Persist.data.clipPins = [p].concat(root.pins);
                pinProc.pending = null;
            }
        }
    }

    // ── history + thumbnails ──
    Process {
        id: proc
        command: ["cliphist", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.entries = text.split("\n").filter(l => l.includes("\t")).slice(0, 200).map(l => {
                    const i = l.indexOf("\t");
                    const body = l.slice(i + 1);
                    const id = l.slice(0, i);
                    const isImage = /^\[\[ binary data/.test(body);
                    return { id, text: body, isImage, thumb: isImage ? root.thumbDir + "/" + id + ".png" : "" };
                });
                // Decode the newest images once (skips ones already there)
                const ids = root.entries.filter(e => e.isImage).slice(0, 30).map(e => e.id);
                if (ids.length) {
                    thumbs.command = ["sh", "-c", 'd=$1; shift; mkdir -p "$d" && chmod 700 "$d"; for id; do [ -s "$d/$id.png" ] || cliphist decode "$id" > "$d/$id.png"; done', "sh", root.thumbDir].concat(ids);
                    thumbs.running = true;
                }
            }
        }
    }
    Process { id: thumbs; onExited: root.thumbVersion++ }
}
