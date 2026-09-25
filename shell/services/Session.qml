pragma Singleton

// Session actions and the power menu's open state.
// Destructive actions (logout, restart, shut down) are confirmed in the UI;
// this service only executes what it is told.
import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root

    property bool menuOpen: false
    function toggleMenu() { menuOpen = !menuOpen; }

    readonly property var actions: [
        { id: "lock",     icon: "lock",               label: "Lock",      key: "L", confirm: false },
        { id: "suspend",  icon: "bedtime",            label: "Sleep",     key: "S", confirm: false },
        { id: "logout",   icon: "logout",             label: "Log out",   key: "E", confirm: true },
        { id: "reboot",   icon: "restart_alt",        label: "Restart",   key: "R", confirm: true },
        { id: "poweroff", icon: "power_settings_new", label: "Shut down", key: "P", confirm: true },
    ]

    function run(id) {
        menuOpen = false;
        switch (id) {
        case "lock":     Lock.lock(); break;
        case "suspend":  Quickshell.execDetached(["systemctl", "suspend"]); break;
        case "logout":   Hyprland.dispatch("exit"); break;
        case "reboot":   Quickshell.execDetached(["systemctl", "reboot"]); break;
        case "poweroff": Quickshell.execDetached(["systemctl", "poweroff"]); break;
        }
    }
}
