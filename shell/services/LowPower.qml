pragma Singleton
// Lighter visuals on a low battery (unplugged, 20 % or less): blur drops to one
// light pass and the music visualiser rests (it runs cava). Your own blur
// settings come back the moment you plug in or it's charged past 20 %.
// The main shell does this, never the Settings app.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    readonly property bool active: Battery.low && Persist.automates
    property var saved: null            // { passes, size } before lightening

    onActiveChanged: active ? lighten() : restore()
    Component.onCompleted: if (active) lighten()

    function lighten() {
        reader.running = true;          // remember yours first, then lighten
    }
    function restore() {
        if (!saved) return;
        Quickshell.execDetached(["hyprctl", "eval", `hl.config({ decoration = { blur = { passes = ${saved.passes}, size = ${saved.size} } } })`]);
        saved = null;
        Island.system("battery_full", "Visuals back to normal", "");
    }
    Process {
        id: reader
        command: ["sh", "-c", 'hyprctl getoption decoration:blur:passes | sed -n "s/^int: //p"; hyprctl getoption decoration:blur:size | sed -n "s/^int: //p"']
        stdout: StdioCollector {
            onStreamFinished: {
                const v = text.trim().split(/\s+/).map(Number);
                if (!root.active || v.length < 2 || isNaN(v[0])) return;
                if (!root.saved) root.saved = { passes: v[0], size: v[1] };
                Quickshell.execDetached(["hyprctl", "eval", "hl.config({ decoration = { blur = { passes = 1, size = 4 } } })"]);
                Island.system("battery_saver", "Lighter visuals", "Battery " + Math.round(Battery.percentage * 100) + "% — less blur, the visualiser rests");
            }
        }
    }
}
