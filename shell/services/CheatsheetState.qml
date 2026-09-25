pragma Singleton
// Open state for the keyboard & gestures cheatsheet (one shortcut, any number of screens)
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io

Singleton {
    id: root
    property bool open: false
    GlobalShortcut { appid: "lumen"; name: "cheatsheet"; description: "Keyboard cheatsheet"; onPressed: root.open = !root.open }
    IpcHandler {
        target: "cheatsheet"
        function open(): void { root.open = true; }
        function toggle(): void { root.open = !root.open; }
    }
}
