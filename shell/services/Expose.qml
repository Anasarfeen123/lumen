pragma Singleton
// Exposé (Super+Shift+Tab, "All windows" in search): every window on every
// workspace, live, in one grid on the focused screen. Type to filter, arrows
// to move, Enter or click to go there, middle-click closes, Esc leaves.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    property bool open: false
    property var items: []              // { address, cls, title, workspace, wsId, toplevel }
    function show() {
        if (open) { open = false; return; }
        clients.running = true;
    }
    function go(it) {
        open = false;
        if (it) Hypr.focusWindow(it.address);
    }
    Process {
        id: clients
        command: ["hyprctl", "clients", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let list; try { list = JSON.parse(text); } catch (e) { return; }
                const tops = Hyprland.toplevels.values;
                root.items = list.filter(c => c.mapped && !c.hidden && (c.workspace?.id ?? -1) > 0)
                                 .sort((a, b) => a.workspace.id - b.workspace.id || a.focusHistoryID - b.focusHistoryID)
                                 .map(c => ({ address: c.address, cls: c.class, title: c.title, workspace: c.workspace?.name ?? "", wsId: c.workspace?.id ?? 0,
                                              w: c.size?.[0] ?? 16, h: c.size?.[1] ?? 9,
                                              toplevel: tops.find(t => "0x" + t.address === c.address) ?? null }));
                if (root.items.length) root.open = true;
            }
        }
    }
    GlobalShortcut { appid: "lumen"; name: "expose"; description: "All windows (Exposé)"; onPressed: root.show() }
    IpcHandler { target: "expose"; function toggle(): void { root.show(); } function close(): void { root.open = false; } }
}
