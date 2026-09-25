pragma Singleton

// Overview / launcher state. One overlay: search on top, workspaces below.
//   mode: "search" (apps, windows, calc, web, actions) | "clipboard" | "emoji"
import QtQuick
import Quickshell

Singleton {
    id: root
    property bool open: false
    property string mode: "search"
    property string query: ""
    // True while the overview owns the island's shape: from opening until the
    // search field has morphed back into the island after closing.
    property bool handoff: false

    function show(m) {
        mode = m ?? "search";
        query = "";
        open = true;
    }
    function hide() { open = false; }
    function toggle(m) {
        const target = m ?? "search";
        if (open && mode === target) hide();
        else show(target);
    }
}
