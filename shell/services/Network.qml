pragma Singleton

// Wi-Fi state via NetworkManager (Quickshell.Networking, event-driven).
// Note: this backend only models Wi-Fi devices; wired links are not reported.
import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Io

Singleton {
    id: root

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property var wifiDevice: Networking.devices.values.find(d => d.type === DeviceType.Wifi) ?? null
    readonly property var active: wifiDevice?.networks?.values.find(n => n.connected) ?? null
    readonly property bool connected: active !== null
    readonly property bool connecting: wifiDevice?.state === DeviceConnectionState.Connecting
    readonly property string ssid: active?.name ?? ""
    // signalStrength is 0–1; normalise defensively in case a backend reports 0–100
    readonly property real strength: {
        const s = active?.signalStrength ?? 0;
        return s > 1 ? s / 100 : s;
    }

    readonly property string icon: {
        if (wired && !connected) return "lan";
        if (!wifiEnabled) return "wifi_off";
        if (connecting) return "wifi_find";
        if (!connected) return "signal_wifi_statusbar_not_connected";
        if (strength > 0.75) return "signal_wifi_4_bar";
        if (strength > 0.5) return "network_wifi_3_bar";
        if (strength > 0.25) return "network_wifi_2_bar";
        return "network_wifi_1_bar";
    }

    // Visible networks: the connected one, then saved ones, then the rest,
    // each strongest first. Hidden networks (no name) are left out.
    readonly property var networks: (wifiDevice?.networks?.values ?? []).filter(n => (n.name ?? "") !== "").sort((a, b) =>
        (b.connected - a.connected) || (b.known - a.known) || (b.signalStrength - a.signalStrength))

    // Ethernet (the Wi-Fi backend doesn't model wired links): NetworkManager's
    // own event stream triggers a one-line device query — no polling.
    property bool wired: false
    Process {
        running: true
        command: ["nmcli", "monitor"]
        stdout: SplitParser { onRead: wiredCheck.restart() }
    }
    Timer { id: wiredCheck; interval: 400; running: true; onTriggered: wiredQuery.running = true }
    Process {
        id: wiredQuery
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "device"]
        stdout: StdioCollector { onStreamFinished: root.wired = /^ethernet:connected$/m.test(text) }
    }

    function disconnectFrom(n) { n.disconnect(); }
    function forget(n) { n.forget(); }

    // Scan only while someone is looking at the list (DESIGN.md §0: fast is a feature)
    property bool scanning: false
    onScanningChanged: if (wifiDevice) wifiDevice.scannerEnabled = scanning

    property string lastError: ""
    signal connectFailed(string ssid)

    function setWifiEnabled(on) { Networking.wifiEnabled = on; }
    function isSecure(n) { return n.security !== WifiSecurityType.Open && n.security !== WifiSecurityType.Unknown; }
    function needsPassword(n) { return !n.known && isSecure(n); }

    // Known or open networks connect directly through NetworkManager.
    // New secured networks go through `nmcli --ask`, with the password written
    // to its stdin, so it never appears in a process list or on disk.
    function connectTo(n, password) {
        if (!needsPassword(n)) { n.connect(); return; }
        joiner.ssid = n.name;
        joiner.password = password;
        joiner.command = ["nmcli", "--ask", "device", "wifi", "connect", n.name];
        joiner.running = true;
    }

    Process {
        id: joiner
        property string ssid: ""
        property string password: ""
        stdinEnabled: true
        onStarted: { write(password + "\n"); password = ""; }
        onExited: code => { if (code !== 0) root.connectFailed(ssid); }
    }
}
