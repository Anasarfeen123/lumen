pragma Singleton
// Alt+Tab window switcher state.
//   Alt+Tab / Alt+Shift+Tab   open, step forward / back (most recent first)
//   Alt+`                     only windows of the focused app
//   release Alt               switch to the selected window
//   Esc cancels · Q closes the selected window · Enter / click switches
// The Alt release comes from a transparent release bind in keybinds.lua
// (switcherCommit); the switcher window's own key-release is a backup.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    property bool open: false
    property int index: 0
    property var items: []                 // { address, cls, title, workspace, toplevel }
    property bool appMode: false
    property var pending: null             // { dir, sameApp } while the list loads

    function start(dir, sameApp) {
        if (open) { if (!!sameApp === appMode) step(dir); return; }
        pending = { dir, sameApp: !!sameApp };
        clients.running = true;
    }
    function step(d) { if (items.length) index = (index + d + items.length) % items.length; }
    // Close first, focus a beat later: while the switcher holds the keyboard,
    // Hyprland would hand focus back to the previous window as it closes.
    property string target: ""
    function commit() {
        if (!open) return;
        target = items[index]?.address ?? "";
        open = false;
        focusLater.restart();
    }
    Timer { id: focusLater; interval: 60; onTriggered: if (root.target) Hypr.focusWindow(root.target) }
    function cancel() { open = false; }
    function closeSelected() {
        const it = items[index];
        if (!it) return;
        Hypr.closeWindow(it.address);
        const rest = items.filter((_, i) => i !== index);
        if (rest.length === 0) { open = false; return; }
        items = rest;
        index = Math.min(index, rest.length - 1);
    }

    Process {
        id: clients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list;
                try { list = JSON.parse(text); } catch (e) { return; }
                list = list.filter(c => c.mapped && !c.hidden && (c.workspace?.id ?? -1) > 0)
                           .sort((a, b) => a.focusHistoryID - b.focusHistoryID);
                const p = root.pending ?? { dir: 1, sameApp: false };
                if (p.sameApp && list.length) list = list.filter(c => c.class === list[0].class);
                const tops = Hyprland.toplevels.values;
                root.items = list.map(c => ({
                    address: c.address, cls: c.class, title: c.title, workspace: c.workspace?.name ?? "",
                    toplevel: tops.find(t => "0x" + t.address === c.address) ?? null,
                }));
                if (root.items.length === 0) return;
                root.appMode = p.sameApp;
                root.index = root.items.length > 1 ? (p.dir > 0 ? 1 : root.items.length - 1) : 0;
                root.open = true;
            }
        }
    }

    GlobalShortcut { appid: "lumen"; name: "switcherNext"; description: "Switch windows"; onPressed: root.start(1, false) }
    GlobalShortcut { appid: "lumen"; name: "switcherPrev"; description: "Switch windows (back)"; onPressed: root.start(-1, false) }
    GlobalShortcut { appid: "lumen"; name: "switcherApp"; description: "Switch windows of this app"; onPressed: root.start(1, true) }
    GlobalShortcut { appid: "lumen"; name: "switcherCommit"; description: "Switcher: Alt released"; onReleased: root.commit(); onPressed: root.commit() }

    IpcHandler {
        target: "switcher"
        function next(): void { root.start(1, false); }
        function prev(): void { root.start(-1, false); }
        function commit(): void { root.commit(); }
        function cancel(): void { root.cancel(); }
    }
}
