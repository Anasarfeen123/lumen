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
        property bool quiet: true
        running: true             // at startup too, so the bar's Caps Lock badge is right after a reload
        command: ["sh", "-c", "cat /sys/class/leds/*::capslock/brightness 2>/dev/null | sort -r | head -1"]
        stdout: StdioCollector {
            onStreamFinished: {
                const on = text.trim() !== "" && text.trim() !== "0";
                const changed = on !== root.caps;
                root.caps = on;
                if (led.quiet) { led.quiet = false; return; }          // the startup read: just know, don't announce
                if (!changed) return;                                    // a re-read that found nothing new
                Island.push({ kind: "system", key: "capslock", priority: Island.priority.osd, duration: 1200, force: true,
                              data: { icon: on ? "keyboard_capslock_badge" : "keyboard_capslock", title: on ? "Caps Lock on" : "Caps Lock off", detail: "", tone: "normal" } });
            }
        }
    }
    // Caps Lock turns ON when pressed but OFF only when released, so one read
    // just after the press always saw "still on" when turning it off: read
    // again once the key is surely up (a long press: the last read catches it)
    property int reads: 0
    Timer { id: readSoon; interval: 60; onTriggered: { led.running = true; if (++root.reads < 3) { interval = root.reads === 1 ? 350 : 1200; restart(); } } }
    function check() { reads = 0; readSoon.interval = 60; readSoon.restart(); }
    GlobalShortcut { appid: "lumen"; name: "capsLock"; description: "Caps Lock pressed (indicator)"; onPressed: root.check() }

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
