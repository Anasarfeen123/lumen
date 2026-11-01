pragma Singleton
// Reopen what you just closed (Ctrl+Super+Shift+T, or "Reopen …" in search):
// the apps whose last window you closed, newest first, back on the
// workspace they were on. Lumen's own windows, dialogs and portals don't count.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root
    property var open: ({})             // address → { cls, ws }
    property var closed: []             // [{ cls, ws, name, at }] newest first, at most 10
    readonly property var last: closed[0] ?? null
    readonly property var skip: /^(org\.quickshell|xdg-desktop-portal|org\.freedesktop\.impl\.portal|polkit|lumen-|pinentry|kitty-scratch)/

    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name === "openwindow") {
                const p = ev.data.split(",");                // address,workspace,class,title
                if (!p[2] || root.skip.test(p[2])) return;
                const o = Object.assign({}, root.open); o["0x" + p[0].replace(/^0x/, "")] = { cls: p[2], ws: p[1] }; root.open = o;
            } else if (ev.name === "closewindow") {
                const a = "0x" + ev.data.replace(/^0x/, "");
                const w = root.open[a];
                if (!w) return;
                const o = Object.assign({}, root.open); delete o[a]; root.open = o;
                // only the app's LAST window: closing one of three browser windows isn't "closed the browser"
                if (Object.values(o).some(x => x.cls === w.cls)) return;
                const e = Apps.entryFor(w.cls);
                if (!e) return;
                root.closed = [{ cls: w.cls, ws: w.ws, name: e.name, at: Date.now() }].concat(root.closed.filter(c => c.cls !== w.cls)).slice(0, 10);
            }
        }
    }
    // windows already open when the shell starts
    Component.onCompleted: {
        const o = {};
        for (const t of Hyprland.toplevels.values) {
            const c = t.lastIpcObject?.class ?? "";
            if (c && !skip.test(c)) o["0x" + t.address] = { cls: c, ws: String(t.workspace?.name ?? "") };
        }
        open = o;
    }

    function reopen(i) {
        const c = closed[i ?? 0];
        if (!c) { Island.system("history", "Nothing closed lately", ""); return; }
        const e = Apps.entryFor(c.cls);
        closed = closed.filter(x => x !== c);
        if (!e) return;
        if (c.ws && /^\d+$/.test(c.ws)) Hypr.workspace(c.ws);
        Apps.launch(e);
        Island.system("history", "Reopening " + e.name, "");
    }
    GlobalShortcut { appid: "lumen"; name: "reopenClosed"; description: "Reopen the app you just closed"; onPressed: root.reopen(0) }
    IpcHandler { target: "closed"; function reopen(): void { root.reopen(0); } function list(): string { return JSON.stringify({ open: Object.keys(root.open).length, closed: root.closed.map(c => c.name) }); } }
}
