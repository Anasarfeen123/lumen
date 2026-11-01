pragma Singleton
// Your own widgets (docs/WIDGETS.md): folders in ~/.local/share/lumen/widgets/
// (not ~/.config/lumen — that's the Lumen repository), each a widget.json and a
// QML file. A widget is code that runs inside the shell, so a new one stays off
// until you turn it on in Settings → Appearance → Your widgets.
//   kind "card"     a card in the Controls sidebar (its own section)
//   kind "desktop"  on the wallpaper, top-right
// It gets one object, `lumen` (the API below), and needs only `import QtQuick`.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    readonly property string dir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/lumen/widgets"
    property var all: []                // [{ id, name, description, kind, entry, needs, path, version, source }]
    readonly property var enabled: Persist.data.widgetsEnabled ?? []
    function isOn(id) { return enabled.includes(id); }
    function setOn(id, on) { Persist.data.widgetsEnabled = on ? enabled.filter(x => x !== id).concat([id]) : enabled.filter(x => x !== id); }
    readonly property var cards: all.filter(w => w.kind === "card" && isOn(w.id))
    readonly property var desktop: all.filter(w => w.kind === "desktop" && isOn(w.id))
    function rescan() { scan.running = false; scan.running = true; }
    function openFolder() { Quickshell.execDetached(["sh", "-c", 'mkdir -p "$1" && xdg-open "$1"', "sh", dir]); }

    // what a widget can use — documented in docs/WIDGETS.md; keep it stable
    readonly property var api: ({
        version: 1,
        theme: Theme, media: Media, weather: Weather, battery: Battery, sysinfo: Sysinfo,
        notifications: Notifications, planner: Planner, college: Amazecc, focus: Focus,
        run: cmd => Quickshell.execDetached(Array.isArray(cmd) ? cmd : ["sh", "-c", String(cmd)]),
        open: url => Qt.openUrlExternally(url),
        askHalo: text => { Ai.show(); Ai.send(String(text)); },
        say: (title, text) => Halo.say({ key: "widget", icon: "widgets", title: String(title), text: String(text ?? ""), level: "asked", duration: 6000, speak: false })
    })

    Process {
        id: scan
        running: true
        // every widget.json, with the folder it's in
        command: ["sh", "-c", 'for f in "$1"/*/widget.json; do [ -f "$f" ] || continue; d=${f%/widget.json}; jq -c --arg d "$d" --arg id "${d##*/}" ". + {path: \\$d, id: \\$id}" "$f" 2>/dev/null; done', "sh", root.dir]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const l of text.split("\n")) {
                    let w = null; try { w = JSON.parse(l); } catch (e) { continue; }
                    if (!/^[a-z0-9][a-z0-9._-]*$/.test(w.id) || !["card", "desktop"].includes(w.kind)) continue;
                    w.entry = /^[A-Za-z0-9_.-]+\.qml$/.test(w.entry ?? "") ? w.entry : "main.qml";
                    w.name = w.name || w.id; w.needs = Array.isArray(w.needs) ? w.needs : [];
                    out.push(w);
                }
                root.all = out.sort((a, b) => a.name.localeCompare(b.name));
            }
        }
    }
    // a folder added, removed or edited: look again
    FileView { path: root.dir + "/.changed"; watchChanges: true; printErrors: false; onFileChanged: root.rescan() }
    IpcHandler {
        target: "widgets"
        function reload(): void { root.rescan(); }
        function list(): string { return JSON.stringify(root.all.map(w => ({ id: w.id, kind: w.kind, on: root.isOn(w.id) }))); }
        function enable(id: string): void { root.setOn(id, true); }
        function disable(id: string): void { root.setOn(id, false); }
    }
}
