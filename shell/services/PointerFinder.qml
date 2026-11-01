pragma Singleton
// "Where's my pointer?" — Ctrl+Super+F (or "Find my pointer" in search): rings
// close in on the pointer and the rest of the screen dims for a moment
// (modules/pointer/PointerFinderOverlay.qml, on the screen it's on).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root
    property point at: Qt.point(0, 0)       // global position
    property int seq: 0                     // bumps on every find (the overlay restarts)
    function find() { pos.running = false; pos.running = true; }
    // shaken (services/PointerGestures.qml): the pointer itself grows for a moment
    // too, then shrinks back — as on a Mac
    // The pointer grows in steps and settles back gently (setcursor can't
    // animate; a few sizes in a row read as motion), holding big while you
    // keep shaking.
    readonly property var growSteps: [1.5, 2.1, 2.6]
    readonly property var shrinkSteps: [2.2, 1.8, 1.45, 1.2, 1]
    property int step: -1
    property bool big: false
    function setSize(f) {
        const p = Theme.tokens.cursor ?? {};
        if (p.theme) Quickshell.execDetached(["hyprctl", "setcursor", p.theme, String(Math.round((p.size ?? 24) * f))]);
    }
    function wiggle() {
        find();
        hold.restart();
        if (big) return;                  // already big: just stay big a little longer
        big = true; step = 0; grow.restart();
    }
    Timer { id: grow; interval: 30; repeat: true
            onTriggered: { root.setSize(root.growSteps[root.step]); if (++root.step >= root.growSteps.length) stop(); } }
    Timer { id: hold; interval: 900; onTriggered: { root.step = 0; settle.restart(); } }
    Timer { id: settle; interval: 45; repeat: true
            onTriggered: { root.setSize(root.shrinkSteps[root.step]); if (++root.step >= root.shrinkSteps.length) { stop(); root.big = false; } } }
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
    IpcHandler { target: "pointer"; function find(): void { root.find(); } function wiggle(): void { root.wiggle(); } }
}
