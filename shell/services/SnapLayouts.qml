pragma Singleton
// Snap layouts (Super+K, or the app menu): a small panel of layouts — halves,
// thirds, ⅔ + ⅓, quarters, a side and a stack, centred, full — for the window
// you were using. Click a zone (or press its number) and the window floats into
// it, inside the bar and the screen's gaps. Esc closes.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    property bool open: false
    property string address: ""         // the window it acts on (focused when it opened)
    property string title: ""

    // [label, [[x, y, w, h] as fractions of the usable area]]
    readonly property var layouts: [
        { label: "Halves", zones: [[0, 0, .5, 1], [.5, 0, .5, 1]] },
        { label: "Thirds", zones: [[0, 0, 1/3, 1], [1/3, 0, 1/3, 1], [2/3, 0, 1/3, 1]] },
        { label: "⅔ + ⅓", zones: [[0, 0, 2/3, 1], [2/3, 0, 1/3, 1]] },
        { label: "Quarters", zones: [[0, 0, .5, .5], [.5, 0, .5, .5], [0, .5, .5, .5], [.5, .5, .5, .5]] },
        { label: "Side + stack", zones: [[0, 0, .5, 1], [.5, 0, .5, .5], [.5, .5, .5, .5]] },
        { label: "Centre · full", zones: [[.15, .08, .7, .84], [0, 0, 1, 1]] }
    ]

    function show() {
        const t = Hyprland.activeToplevel?.lastIpcObject;
        if (!t?.address) { Island.system("dashboard_customize", "No window to place", "Focus one first"); return; }
        address = t.address; title = t.title ?? ""; open = true;
        Hyprland.refreshMonitors();         // the reserved space (the bar) can be stale
    }
    function toggle() { open ? (open = false) : show(); }

    function apply(z) {
        open = false;
        const w = Hyprland.toplevels.values.map(t => t.lastIpcObject ?? {}).find(o => o.address === address);
        const m = Hyprland.monitors.values.map(x => x.lastIpcObject ?? {}).find(x => x.id === w?.monitor) ?? Hyprland.focusedMonitor?.lastIpcObject;
        if (!w || !m) return;
        const scale = m.scale || 1;
        // left, top, right, bottom — if Hyprland hasn't told us yet, at least the bar
        const res = (m.reserved ?? []).some(v => v > 0) ? m.reserved : [0, Theme.edgeGap + Theme.barHeight, 0, 0];
        const gap = 4, ax = m.x + res[0], ay = m.y + res[1];
        const aw = m.width / scale - res[0] - res[2], ah = m.height / scale - res[1] - res[3];
        const x = Math.round(ax + z[0] * aw + gap), y = Math.round(ay + z[1] * ah + gap);
        const ww = Math.round(z[2] * aw - 2 * gap), hh = Math.round(z[3] * ah - 2 * gap);
        const win = JSON.stringify("address:" + address);
        Hypr.d(`hl.dsp.focus({ window = ${win} })`);
        if (!w.floating) Hypr.d(`hl.dsp.window.float({ action = "enable" })`);
        Hypr.d(`hl.dsp.window.resize({ x = ${ww}, y = ${hh}, relative = false })`);
        Hypr.d(`hl.dsp.window.move({ x = ${x}, y = ${y}, relative = false })`);
    }

    GlobalShortcut { appid: "lumen"; name: "snap"; description: "Snap layouts"; onPressed: root.toggle() }
    IpcHandler {
        target: "snap"
        function toggle(): void { root.toggle(); }
        // zone n (1-based, reading order) for the focused window
        function zone(n: int): void { const all = [].concat(...root.layouts.map(l => l.zones)); root.show(); if (all[n - 1]) root.apply(all[n - 1]); }
    }
}
