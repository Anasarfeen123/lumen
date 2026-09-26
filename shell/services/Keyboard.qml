pragma Singleton
// Caps Lock and keyboard layout, shown briefly in the island.
//   Caps Lock: a pass-through bind on the key (keybinds.lua → lumen:capsLock)
//              makes us read the keyboard LED (Hyprland doesn't report it)
//   layout:    Hyprland's "activelayout" event
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

Singleton {
    id: root
    property bool caps: false
    property string layout: ""

    Process {
        id: led
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null | sort -r | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const on = text.trim() !== "" && text.trim() !== "0";
                root.caps = on;
                Island.push({ kind: "system", key: "capslock", priority: Island.priority.osd, duration: 1200, force: true,
                              data: { icon: on ? "keyboard_capslock_badge" : "keyboard_capslock", title: on ? "Caps Lock on" : "Caps Lock off", detail: "", tone: "normal" } });
            }
        }
    }
    Timer { id: readSoon; interval: 60; onTriggered: led.running = true }      // let the LED settle
    GlobalShortcut { appid: "lumen"; name: "capsLock"; description: "Caps Lock pressed (indicator)"; onPressed: readSoon.restart() }

    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (event.name !== "activelayout") return;
            const name = event.data.split(",").slice(1).join(",").trim();
            if (!name || name === root.layout) { root.layout = name; return; }
            const first = root.layout === "";
            root.layout = name;
            if (!first) Island.system("keyboard", name, "Keyboard layout");
        }
    }
}
