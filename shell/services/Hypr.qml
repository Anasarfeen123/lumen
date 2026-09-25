pragma Singleton

// The one place the shell tells Hyprland what to do. Lumen's Hyprland config
// is Lua (Hyprland ≥ 0.56; the .conf format is removed in 0.57), where a
// dispatch is a Lua expression, e.g. `hl.dsp.focus({ workspace = 3 })`.
// Keeping every expression here means a future API change is one file.
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root

    // Lua literal for a workspace: numbers stay numbers, the rest are strings
    function ws(w) { return typeof w === "number" ? String(w) : JSON.stringify(String(w)); }
    function win(address) { return JSON.stringify("address:" + address); }
    function d(expr) { Hyprland.dispatch(expr); }

    function workspace(w) { d(`hl.dsp.focus({ workspace = ${ws(w)} })`); }
    function focusWindow(address) { d(`hl.dsp.focus({ window = ${win(address)} })`); }
    function moveToWorkspace(address, w, follow) {
        d(`hl.dsp.window.move({ workspace = ${ws(w)}, follow = ${follow ? "true" : "false"}, window = ${win(address)} })`);
    }
    function closeWindow(address) { d(`hl.dsp.window.close({ window = ${win(address)} })`); }
    function killWindow(address) { d(`hl.dsp.window.kill({ window = ${win(address)} })`); }
    function toggleFloat(address) { d(`hl.dsp.window.float({ action = "toggle", window = ${win(address)} })`); }
    function pin(address) { d(`hl.dsp.window.pin({ window = ${win(address)} })`); }
    function fullscreen(mode) { d(`hl.dsp.window.fullscreen({ mode = "${mode}", action = "toggle" })`); }  // "fullscreen" | "maximized"
    function exit() { d(`hl.dsp.exit()`); }

    // Runtime config (not persisted; `hyprctl reload` restores the files)
    function set(luaTable) { Quickshell.execDetached(["hyprctl", "eval", `hl.config(${luaTable})`]); }
}
