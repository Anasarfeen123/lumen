pragma Singleton
// Picture-in-picture for any window (scripts/pip.py): pop the video you're
// watching — or the music player, or a call — into a pinned corner that
// follows you across workspaces; move it round the corners, make it bigger or
// smaller, put it back exactly where it was. Browser PiP windows count too.
//   Ctrl+Super+P · the island's player (⧉) · Halo: "picture in picture",
//   "move the pip to the top left", "make it bigger", "put it back"
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root
    readonly property string script: Theme.lumenRoot + "/scripts/pip.py"
    property var state: ({})            // { address, title, class, corner, size, browser? }
    readonly property bool active: !!state.address

    function refresh() { if (!stateProc.running) stateProc.running = true; }
    Process { id: stateProc; running: true; command: [root.script, "state"]
              stdout: StdioCollector { onStreamFinished: { try { root.state = JSON.parse(text); } catch (e) { root.state = ({}); } } } }
    Connections {
        target: Hyprland
        function onRawEvent(ev) { if (/^(closewindow|openwindow|pin|changefloatingmode|windowtitlev2)$/.test(ev.name)) refreshSoon.restart(); }
    }
    Timer { id: refreshSoon; interval: 300; onTriggered: root.refresh() }

    function run(args, say) {
        const p = runner.createObject(root, { say });
        p.command = [script].concat(args);
        p.running = true;
    }
    Component {
        id: runner
        Process {
            id: rp
            property string say: ""
            stdout: StdioCollector {
                onStreamFinished: {
                    let r = {}; try { r = JSON.parse(text); } catch (e) {}
                    if (r.ok === false) Island.system("picture_in_picture_alt", r.error || "Couldn't do that", "");
                    else if (rp.say) Island.system("picture_in_picture_alt", rp.say, r.title ?? "");
                    root.refresh();
                    rp.destroy();
                }
            }
        }
    }
    function pop(address) { run(["pop"].concat(address ? [address] : []), "Picture in picture"); }
    function back() { run(["back"], "Back in its place"); }
    function toggle() { if (active && !state.browser) back(); else pop(""); }
    function corner(c) { run(["corner", c ?? "next"], ""); }
    function size(s) { run(["size", s], ""); }

    // The music/video player's own window (for "pop it out" from the island)
    function playerWindow() {
        const p = Media.active;
        if (!p) return null;
        const keys = [p.desktopEntry, p.identity].filter(x => x).map(x => String(x).toLowerCase().replace(/\s+/g, ""));
        return Hyprland.toplevels.values.map(t => t.lastIpcObject ?? {}).find(o => {
            const c = (o.class ?? "").toLowerCase(), t = (o.title ?? "").toLowerCase();
            return keys.some(k => c.includes(k) || k.includes(c) && c.length > 3) || (Media.title && t.includes(Media.title.toLowerCase().slice(0, 24)));
        }) ?? null;
    }
    function popPlayer() { const w = playerWindow(); if (w?.address) pop(w.address); else Island.system("picture_in_picture_alt", "No window for this player", "It may be playing in the background"); }

    GlobalShortcut { appid: "lumen"; name: "pip"; description: "Picture in picture (the focused window)"; onPressed: root.toggle() }
    IpcHandler {
        target: "pip"
        function toggle(): void { root.toggle(); }
        function corner(c: string): void { root.corner(c); }
        function size(s: string): void { root.size(s); }
        function state(): string { return JSON.stringify(root.state); }
    }
}
