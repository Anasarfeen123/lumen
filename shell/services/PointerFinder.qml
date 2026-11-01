pragma Singleton
// "Where's my pointer?" — Ctrl+Super+F (or "Find my pointer" in search): rings
// close in on the pointer and the rest of the screen dims for a moment
// (modules/pointer/PointerFinderOverlay.qml, on the screen it's on).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    property point at: Qt.point(0, 0)       // global position
    property int seq: 0                     // bumps on every find (the overlay restarts)
    function find() { pos.running = false; pos.running = true; }
    Process {
        id: pos
        command: ["hyprctl", "cursorpos", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                let p = null; try { p = JSON.parse(text); } catch (e) { return; }
                root.at = Qt.point(p.x, p.y);
                root.seq++;
            }
        }
    }
    GlobalShortcut { appid: "lumen"; name: "findPointer"; description: "Find my pointer"; onPressed: root.find() }
    IpcHandler { target: "pointer"; function find(): void { root.find(); } }
}
