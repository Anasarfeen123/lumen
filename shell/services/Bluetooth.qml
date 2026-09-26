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

    // A Material Symbol for a BlueZ device icon name
    function glyph(icon) {
        if (/headset|headphone|audio-card/.test(icon)) return "headphones";
        if (/speaker|audio/.test(icon)) return "speaker";
        if (/mouse/.test(icon)) return "mouse";
        if (/keyboard/.test(icon)) return "keyboard";
        if (/phone/.test(icon)) return "smartphone";
        if (/computer|laptop/.test(icon)) return "laptop";
        if (/gaming|joystick/.test(icon)) return "sports_esports";
        if (/watch/.test(icon)) return "watch";
        if (/tablet/.test(icon)) return "tablet";
        return "bluetooth";
    }

    // Devices in range that aren't paired yet (only while someone is looking:
    // discovery costs radio time). Nameless beacons are left out.
    property bool scanning: false
    onScanningChanged: if (adapter && enabled) adapter.discovering = scanning
    onEnabledChanged: if (adapter && enabled && scanning) adapter.discovering = true
    readonly property bool discovering: adapter?.discovering ?? false
    readonly property var nearby: (adapter?.devices?.values ?? []).filter(d => !d.paired && d.name && !/^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i.test(d.name))

    function setEnabled(on) { if (adapter) adapter.enabled = on; }
    function toggleDevice(d) { if (d.connected) d.disconnect(); else d.connect(); }
    function forget(d) { d.forget(); }

    // Pair, trust (so it reconnects by itself next time), then connect.
    // Works for devices that pair without a code — headphones, speakers, most
    // mice and controllers. Keyboards that ask for a PIN use the system's
    // Bluetooth settings.
    property var pairing: null
    signal pairFailed(string name)
    function pair(d) { pairing = d; d.pair(); pairTimeout.restart(); }
    Connections {
        target: root.pairing
        ignoreUnknownSignals: true
        function onPairedChanged() {
            const d = root.pairing;
            if (!d?.paired) return;
            d.trusted = true;
            d.connect();
            root.pairing = null;
            pairTimeout.stop();
        }
    }
    Timer {
        id: pairTimeout
        interval: 30000
        onTriggered: {
            if (!root.pairing) return;
            if (!root.pairing.paired) { root.pairFailed(root.pairing.name || "Device"); root.pairing.cancelPair(); }
            root.pairing = null;
        }
    }

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
