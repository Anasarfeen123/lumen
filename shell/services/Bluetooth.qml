pragma Singleton

// Bluetooth via BlueZ (Quickshell.Bluetooth, event-driven over D-Bus).
import QtQuick
import Quickshell
import Quickshell.Bluetooth as QsBt

Singleton {
    id: root

    readonly property var adapter: QsBt.Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter?.enabled ?? false
    readonly property var connectedDevices: (adapter?.devices?.values ?? []).filter(d => d.connected)
    readonly property bool hasConnection: connectedDevices.length > 0
    readonly property var primary: connectedDevices[0] ?? null

    readonly property string icon: !enabled ? "bluetooth_disabled"
                                 : hasConnection ? "bluetooth_connected" : "bluetooth"

    // Paired devices, connected first
    readonly property var paired: (adapter?.devices?.values ?? []).filter(d => d.paired)
                                   .sort((a, b) => b.connected - a.connected)

    function setEnabled(on) { if (adapter) adapter.enabled = on; }
    function toggleDevice(d) { if (d.connected) d.disconnect(); else d.connect(); }

    // Earbuds, mice, keyboards: warn once when a connected device drops below 15 %
    property var warned: ({})
    Timer {
        interval: 60000; running: Persist.automates && root.hasConnection; repeat: true; triggeredOnStart: true
        onTriggered: {
            const w = Object.assign({}, root.warned);
            for (const d of root.connectedDevices) {
                if (!d.batteryAvailable) continue;
                const pct = Math.round(d.battery * 100), key = d.address;
                if (pct <= 15 && !w[key]) { w[key] = true; Island.system("battery_alert", (d.name || "Device") + " battery low", pct + "% left", "warning"); }
                else if (pct > 20) delete w[key];
            }
            root.warned = w;
        }
    }
}
