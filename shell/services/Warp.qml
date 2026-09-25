pragma Singleton
// Cloudflare WARP (warp-cli). The tile appears only when warp-cli is
// installed; status is read on demand (control centre open, after a toggle).
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property bool available: false
    property bool connected: false
    property bool busy: false

    function refresh() { if (!status.running) status.running = true; }
    function toggle() {
        if (!available || busy) return;
        busy = true;
        action.command = ["warp-cli", "--accept-tos", connected ? "disconnect" : "connect"];
        action.running = true;
    }
    Process {
        id: status
        running: true
        command: ["sh", "-c", "command -v warp-cli >/dev/null || exit 3; warp-cli --accept-tos status"]
        stdout: StdioCollector { onStreamFinished: root.connected = /Status update:\s*Connected/i.test(text) }
        onExited: code => root.available = code !== 3
    }
    Process {
        id: action
        onExited: { root.busy = false; settle.restart(); }
    }
    Timer { id: settle; interval: 1500; onTriggered: root.refresh() }
}
