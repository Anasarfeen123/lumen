pragma Singleton

// VPN / WireGuard connections known to NetworkManager. Read on demand (when
// the control centre opens or after a toggle) — there is nothing to poll.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property var connections: []        // [{ name, type, active }]
    readonly property bool available: connections.length > 0
    readonly property var primary: connections.find(c => c.active) ?? connections[0] ?? null
    readonly property bool active: connections.some(c => c.active)

    function refresh() { if (!list.running) list.running = true; }

    function toggle() {
        if (!primary) return;
        toggler.command = ["nmcli", "connection", primary.active ? "down" : "up", "id", primary.name];
        toggler.running = true;
    }

    Process {
        id: list
        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.trim().split("\n")) {
                    // nmcli -t escapes ':' inside fields as '\:'
                    const f = line.split(/(?<!\\):/).map(x => x.replace(/\\:/g, ":"));
                    if (f.length >= 3 && /vpn|wireguard/.test(f[1]))
                        out.push({ name: f[0], type: f[1], active: f[2] === "yes" });
                }
                root.connections = out;
            }
        }
    }

    Process {
        id: toggler
        onExited: code => {
            root.refresh();
            if (code !== 0)
                Island.system("vpn_key_alert", "VPN", "Couldn't change connection", "error");
        }
    }

    Component.onCompleted: refresh()
}
