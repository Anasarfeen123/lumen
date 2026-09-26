pragma Singleton
// Lumen Connect — your phone, through KDE Connect (scripts/connect.sh).
// Status refreshes while the control centre or Settings → Phone is open,
// and every few minutes otherwise (for the low-battery note).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    property bool available: false
    property var devices: []
    readonly property var paired: devices.filter(d => d.paired)
    readonly property var phone: paired.find(d => d.reachable) ?? paired[0] ?? null
    property bool watching: false            // a view that shows devices is open

    readonly property string script: Theme.lumenRoot + "/scripts/connect.sh"
    function refresh() { if (!probe.running) probe.running = true; }
    function act(cmd, id, arg) {
        Quickshell.execDetached(arg !== undefined ? [script, cmd, id, arg] : [script, cmd, id]);
        if (cmd === "ring") Island.system("phone_in_talk", "Ringing " + (devices.find(d => d.id === id)?.name ?? "your phone"), "");
        if (cmd === "send-clipboard") Island.system("content_paste_go", "Clipboard sent", devices.find(d => d.id === id)?.name ?? "");
        if (cmd === "pair" || cmd === "unpair") refreshSoon.restart();
    }
    Timer { id: refreshSoon; interval: 1500; onTriggered: root.refresh() }

    Process {
        id: probe
        command: [root.script, "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { const d = JSON.parse(text); root.available = d.available; root.devices = d.devices ?? []; } catch (e) {}
            }
        }
    }
    Timer { interval: root.watching ? 8000 : 180000; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.refresh() }

    // Phone battery low: one note per drop below 15 %
    property var warned: ({})
    onDevicesChanged: {
        if (!Persist.automates) return;
        const w = Object.assign({}, warned);
        for (const d of devices) {
            if (!d.reachable || d.battery < 0) continue;
            if (d.battery <= 15 && !d.charging && !w[d.id]) { w[d.id] = true; Island.system("battery_alert", d.name + " battery low", d.battery + "% left", "warning"); }
            else if (d.battery > 20 || d.charging) delete w[d.id];
        }
        warned = w;
    }
}
