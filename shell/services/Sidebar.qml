pragma Singleton

// Right-hand panel with two tabs: Controls (control centre) and Notifications.
//   toggle()          open on the last tab / close
//   toggle(tab)       open on that tab; if it's already showing, close
import QtQuick
import Quickshell

Singleton {
    property bool open: false
    property string tab: "controls"          // "controls" | "notifications"

    function toggle(t) {
        if (t && open && tab !== t) { tab = t; return; }
        if (t) tab = t;
        open = !open;
    }
    function show(t) { if (t) tab = t; open = true; }
    function hide() { open = false; }
}
