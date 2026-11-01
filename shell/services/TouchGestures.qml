pragma Singleton
// Touchpad gestures Hyprland can't see (scripts/touch-gestures.py), when
// Settings → Halo → Touchpad gestures is on:
//   rest 3 fingers still   circle to search
//   rest 4 fingers still   talk to Halo while they stay down; lift to send
// The script reads only the touchpad, read-only; not in a test session.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components

Singleton {
    id: root
    readonly property bool on: (Persist.data.touchGestures ?? false) && Quickshell.env("LUMEN_NESTED") !== "1"
    property string error: ""
    SupervisedProcess {
        wanted: root.on && !Lock.locked
        command: [Theme.lumenRoot + "/scripts/touch-gestures.py", "run"]
        stdout: SplitParser {
            onRead: line => {
                let o = {}; try { o = JSON.parse(line); } catch (e) { return; }
                if (o.error) { root.error = o.error; return; }
                if (o.gesture === "circle" && !Lens.open) Lens.start();
                else if (o.gesture === "talk") o.state === "down" ? Converse.press() : Converse.release();
            }
        }
    }
}
