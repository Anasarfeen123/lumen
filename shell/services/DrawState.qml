pragma Singleton
// Draw on the screen (modules/lens/DrawOverlay.qml): Ctrl+Super+D, "draw on
// the screen" in Halo or search. S saves a screenshot with the ink.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root
    property bool open: false
    property bool snapping: false       // the palette hides while the screenshot is taken
    function toggle() { open = !open; }
    // A screenshot of the screen with the ink on it (the palette steps aside for it)
    function snap(monitor) {
        snapper.command = ["sh", "-c", 'd="$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Screenshots"; mkdir -p "$d"; f="$d/Drawing_$(date +%Y-%m-%d_%H-%M-%S).png"; sleep 0.25; grim ${1:+-o "$1"} "$f" && wl-copy --type image/png < "$f" && echo "$f"', "sh", monitor];
        snapping = true;
        snapper.running = true;
    }
    Process {
        id: snapper
        onExited: root.snapping = false
        stdout: StdioCollector { onStreamFinished: { const f = text.trim(); if (f) Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen-shell-ipc", "island", "screenshot", f]); } }
    }
    GlobalShortcut { appid: "lumen"; name: "draw"; description: "Draw on the screen"; onPressed: root.toggle() }
    IpcHandler { target: "draw"; function toggle(): void { root.toggle(); } function close(): void { root.open = false; } }
}
