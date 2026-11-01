pragma Singleton
// Gestures made with the pointer (scripts/pointer-gestures.py), while
// Settings → Appearance → Shake to find the pointer is on (the default):
//   wiggle — shake the mouse (or a finger on the touchpad) quickly side to side
//            → the pointer grows for a moment and rings close in on it
// The script reads pointer devices only, read-only; not in a test session.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components

Singleton {
    id: root
    readonly property bool on: (Persist.data.pointerShake ?? true) && Quickshell.env("LUMEN_NESTED") !== "1"
    SupervisedProcess {
        wanted: root.on && !Lock.locked
        command: [Theme.lumenRoot + "/scripts/pointer-gestures.py", "run"]
        stdout: SplitParser {
            onRead: line => {
                let o = {}; try { o = JSON.parse(line); } catch (e) { return; }
                if (o.gesture === "wiggle") PointerFinder.wiggle();
            }
        }
    }
}
