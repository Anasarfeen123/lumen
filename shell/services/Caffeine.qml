pragma Singleton
// Caffeine: keep the screen awake (no dim, lock, screen-off or sleep) until
// switched off. A Wayland idle inhibitor held by the bar (modules/bar/Bar.qml)
// — hypridle honours it. Session-only on purpose: it never survives a restart.
import QtQuick
import Quickshell

Singleton {
    property bool on: false
    function toggle() { on = !on; }
}
