pragma Singleton
// Gestures made with the pointer (scripts/pointer-gestures.py), while
// Settings → Appearance → Shake to find the pointer is on (the default):
//   wiggle — shake the mouse (or a finger on the touchpad) quickly side to side
//            → the pointer grows for a moment and rings close in on it
// The script reads pointer devices only, read-only; not in a test session.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme
import qs.components

Singleton {
    id: root
    readonly property bool on: (Persist.data.pointerShake ?? true) && Quickshell.env("LUMEN_NESTED") !== "1"
    // a new sensitivity: restart the reader with it
    readonly property string sens: Persist.data.pointerShakeSens ?? "normal"
    property bool cycling: false
    onSensChanged: { cycling = true; back.restart(); }
    Timer { id: back; interval: 300; onTriggered: root.cycling = false }
    SupervisedProcess {
        wanted: root.on && !Lock.locked && !root.cycling
        command: [Theme.lumenRoot + "/scripts/pointer-gestures.py", "run", root.sens]
        stdout: SplitParser {
            onRead: line => {
                let o = {}; try { o = JSON.parse(line); } catch (e) { return; }
                // not over a fullscreen game or video: shaking the mouse is part of playing
                const fs = Hyprland.focusedMonitor?.activeWorkspace?.hasFullscreen ?? false;
                if (o.gesture === "wiggle" && !fs && !GameMode.on) PointerFinder.wiggle();
            }
        }
    }
}
