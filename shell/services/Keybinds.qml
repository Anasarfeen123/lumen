pragma Singleton
// Every keybind, live from Hyprland (`hyprctl binds -j`), grouped by the
// "Section: Label" description each bind carries in hypr/keybinds.lua, plus
// the gestures (which Hyprland can't list). Used by the cheatsheet (Super+/)
// and Settings → Keyboard & Gestures, so neither can drift from reality.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property var sections: []
    function refresh() { binds.running = true; }
    Component.onCompleted: refresh()

    Process {
        id: binds
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { root.sections = root.build(JSON.parse(text)); } catch (e) {} } }
    }

    readonly property var keyNames: ({
        Return: "Enter", grave: "`", Semicolon: ";", Apostrophe: "'", Page_Up: "PgUp", Page_Down: "PgDn",
        mouse_down: "Scroll ↓", mouse_up: "Scroll ↑", "mouse:272": "Drag", "mouse:273": "Right-drag",
        "mouse:275": "Back", "mouse:276": "Forward", SUPER_L: "(tap)", period: ".", Equal: "=", Minus: "−",
        Space: "Space", Escape: "Esc", Delete: "Del", Print: "PrtSc", left: "←", right: "→", up: "↑", down: "↓",
        Tab: "Tab", Slash: "/"
    })
    function build(list) {
        const order = [], bySection = {};
        for (const b of list) {
            const desc = b.description ?? "";
            const i = desc.indexOf(": ");
            if (i < 0) continue;
            const section = desc.slice(0, i);
            // The key caps show "1…0" / arrows, so the label doesn't repeat them
            const label = desc.slice(i + 2).replace(/\s*(1…0|← → ↑ ↓)/, "");
            const keys = [];
            const m = b.modmask ?? 0;
            if (m & 64) keys.push("Super");
            if (m & 4) keys.push("Ctrl");
            if (m & 8) keys.push("Alt");
            if (m & 1) keys.push("Shift");
            let k = keyNames[b.key] ?? (b.key.length === 1 ? b.key.toUpperCase() : b.key);
            if (/1…0/.test(desc)) k = "1…0";
            if (/← → ↑ ↓/.test(desc)) k = "← → ↑ ↓";
            if (b.key === "SUPER_L") { keys.length = 0; keys.push("Super"); }
            keys.push(k);
            if (!bySection[section]) { bySection[section] = []; order.push(section); }
            if (!bySection[section].some(x => x.desc === label)) bySection[section].push({ keys, desc: label });
        }
        const out = order.map(t => ({ title: t, binds: bySection[t] }));
        out.push({ title: "Gestures", binds: [
            { keys: ["Top-left corner"], desc: "Overview & search" },
            { keys: ["Top-right corner"], desc: "Control centre" },
            { keys: ["4 fingers", "↑ / ↓"], desc: "Open / close overview" },
            { keys: ["4 fingers", "← / →"], desc: "Switch workspace" },
            { keys: ["3 fingers", "drag"], desc: "Move window" },
            { keys: ["3 fingers", "pinch"], desc: "Fullscreen" },
            { keys: ["Scroll", "on the bar"], desc: "Switch workspace" },
            { keys: ["Scroll", "on the island"], desc: "Volume (Shift: brightness)" },
            { keys: ["Right-click", "workspaces / island"], desc: "Apps in the background (tray)" },
            { keys: ["Middle-click", "island"], desc: "Play / pause" },
            { keys: ["Swipe →", "notification"], desc: "Dismiss it" },
        ] });
        return out;
    }

}
