pragma Singleton

// Right-hand panel (notification centre now; quick settings join in Phase 7).
import QtQuick
import Quickshell

Singleton {
    property bool open: false
    function toggle() { open = !open; }
    function show() { open = true; }
    function hide() { open = false; }
}
