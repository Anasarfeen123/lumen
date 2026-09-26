pragma Singleton

// Laptop keys (Fn row, ASUS WMI hotkeys, the "project" key …) and the
// feedback each gives in the island. hypr/keybinds.lua sends them here via
// `lumen-shell-ipc keys <fn>`. Some keys are handled by the firmware or the
// kernel instead (Fn+F5 performance on ASUS changes the platform profile
// itself; airplane can be hardware too), so the island also reacts to the
// *changes*, whoever made them.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root

    // ── feedback for changes, whoever made them ──
    property bool _ready: false
    Timer { interval: 3000; running: true; onTriggered: root._ready = true }

    Connections {
        target: Power
        function onProfileChanged() { if (root._ready) Island.system(Power.icon, Power.label, "Power mode"); }
    }
    Connections {
        target: Airplane
        function onOnChanged() {
            if (!root._ready) return;
            Island.system(Airplane.on ? "flight" : "flight_land", Airplane.on ? "Airplane mode on" : "Airplane mode off",
                          Airplane.on ? "Wi-Fi and Bluetooth are off" : "Wi-Fi and Bluetooth are back");
        }
    }

    // ── touchpad ──
    property bool touchpadOn: true
    property var touchpads: []
    Process {
        id: listDevices
        running: true
        command: ["hyprctl", "-j", "devices"]
        stdout: StdioCollector { onStreamFinished: { try { root.touchpads = JSON.parse(text).mice.map(m => m.name).filter(n => /touchpad|trackpad|synaptics|elan|glidepoint/i.test(n)); } catch (e) {} } }
    }
    function setTouchpad(on) {
        if (!touchpads.length) { Island.system("touchpad_mouse_off", "No touchpad found", ""); return; }
        touchpadOn = on;
        for (const n of touchpads) Quickshell.execDetached(["hyprctl", "eval", `hl.device({ name = "${n}", enabled = ${on} })`]);
        Island.system(on ? "touchpad_mouse" : "touchpad_mouse_off", on ? "Touchpad on" : "Touchpad off", on ? "" : "The key again turns it back on");
    }

    // ── keyboard backlight ──
    function kbd(step) {
        if (!KbdLight.available) return;
        const next = Math.max(0, Math.min(KbdLight.max, KbdLight.level + step));
        kbdSet.command = ["brightnessctl", "-m", "-d", KbdLight.device, "set", String(next)];
        kbdSet.running = true;
        KbdLight.level = next;
        Island.osd("kbd", next === 0 ? "keyboard_off" : "keyboard", KbdLight.max > 0 ? next / KbdLight.max : 0, "Keyboard light");
    }
    Process { id: kbdSet }

    // ── displays (Fn+F9 / Super+P) ──
    function display(mode) {
        displayProc.command = [Theme.lumenRoot + "/scripts/display-mode.sh", mode || "next"];
        displayProc.running = true;
    }
    Process {
        id: displayProc
        stdout: StdioCollector {
            onStreamFinished: {
                let d; try { d = JSON.parse(text); } catch (e) { return; }
                const icon = ({ extend: "desktop_windows", mirror: "screen_share", external: "tv", laptop: "laptop", single: "laptop" })[d.mode] ?? "monitor";
                Island.system(icon, d.label, d.detail);
            }
        }
    }
    // "External only" and the external screen goes away → turn the laptop screen back on
    Connections {
        target: Hyprland
        function onRawEvent(ev) { if (ev.name === "monitorremovedv2") root.display("extend"); }
    }

    IpcHandler {
        target: "keys"
        function airplane(): void { Airplane.toggle(); }
        function wifi(): void { Network.setWifiEnabled(!Network.wifiEnabled); Island.system(Network.wifiEnabled ? "wifi_off" : "wifi", Network.wifiEnabled ? "Wi-Fi off" : "Wi-Fi on", ""); }
        function bluetooth(): void { Bluetooth.setEnabled(!Bluetooth.enabled); Island.system(Bluetooth.enabled ? "bluetooth_disabled" : "bluetooth", Bluetooth.enabled ? "Bluetooth off" : "Bluetooth on", ""); }
        function touchpad(): void { root.setTouchpad(!root.touchpadOn); }
        function touchpadOn(): void { root.setTouchpad(true); }
        function touchpadOff(): void { root.setTouchpad(false); }
        function kbdUp(): void { root.kbd(1); }
        function kbdDown(): void { root.kbd(-1); }
        function kbdCycle(): void { root.kbd(KbdLight.level >= KbdLight.max ? -KbdLight.max : 1); }
        function performance(): void { Power.cycle(); }
        function display(): void { root.display("next"); }
        function calculator(): void { Overview.show("search"); Overview.query = "="; }
        function power(): void { Session.menuOpen = true; }
        function camera(): void {
            Quickshell.execDetached(["sh", "-c", 'for a in snapshot kamoso cheese guvcview; do command -v "$a" >/dev/null && exec "$a"; done; exit 1']);
        }
    }
}
