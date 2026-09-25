// Workspaces on this monitor that are in use, the current one, and one empty
// "New" tile to drop windows onto.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme
import qs.services

Row {
    id: root
    required property var monitor           // HyprlandMonitor
    required property real maxWidth
    property int selectedIndex: -1
    signal done()

    spacing: Theme.space.s4

    readonly property int activeId: monitor?.activeWorkspace?.id ?? 1
    readonly property var ids: {
        const s = new Set(Hyprland.workspaces.values
            .filter(w => w.id > 0 && w.monitor?.name === monitor?.name && (w.toplevels?.values?.length ?? 0) > 0)
            .map(w => w.id));
        s.add(activeId);
        const list = [...s].sort((a, b) => a - b);
        let next = 1;
        while (s.has(next)) next++;
        if (next <= 10) list.push(next);
        return list;
    }
    readonly property int newId: ids[ids.length - 1]
    readonly property real tileWidth: Math.min(300, (maxWidth - spacing * (ids.length - 1)) / Math.max(1, ids.length))

    function move(d) {
        if (selectedIndex < 0) selectedIndex = ids.indexOf(activeId);
        selectedIndex = Math.max(0, Math.min(ids.length - 1, selectedIndex + d));
    }
    function activateSelected() {
        if (selectedIndex < 0) return false;
        Hypr.workspace(ids[selectedIndex]);
        return true;
    }

    // Current wallpaper, shown behind each miniature
    FileView {
        id: wp
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/lumen/wallpaper"
    }

    Repeater {
        model: root.ids
        delegate: WorkspaceTile {
            required property int modelData
            required property int index
            wsId: modelData
            monitor: root.monitor
            tileWidth: root.tileWidth
            wallpaper: wp.loaded ? wp.text().trim() : ""
            current: modelData === root.activeId
            selected: index === root.selectedIndex
            isNew: modelData === root.newId && !(Hyprland.workspaces.values.some(w => w.id === modelData && (w.toplevels?.values?.length ?? 0) > 0)) && modelData !== root.activeId
            onDone: root.done()
        }
    }
}
