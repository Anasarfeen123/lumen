pragma Singleton
// Keyboard backlight (first *::kbd_backlight LED), cycled 0 → max → 0.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string device: ""
    property int level: 0
    property int max: 0
    readonly property bool available: device !== "" && max > 0

    function parse(text) {
        // brightnessctl -m: name,class,current,percent,max
        const f = text.trim().split("\n").find(l => /kbd_backlight/.test(l))?.split(",");
        if (!f || f.length < 5) return;
        device = f[0]; level = parseInt(f[2]); max = parseInt(f[4]);
    }
    function cycle() {
        if (!available) return;
        const next = level >= max ? 0 : level + 1;
        setter.command = ["brightnessctl", "-m", "-d", device, "set", String(next)];
        setter.running = true;
    }
    Process {
        running: true
        command: ["brightnessctl", "-l", "-m"]
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }
    Process {
        id: setter
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }
}
