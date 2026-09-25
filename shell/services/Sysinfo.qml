pragma Singleton

// CPU / memory / temperature / GPU / disk, sampled by scripts/system-info.sh.
// Sampling runs ONLY while `active` is true (the control centre is open), so
// the idle desktop spends nothing on it (DESIGN.md §0, §12).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root

    property bool active: false

    property real cpu: 0            // 0–1
    property real memUsed: 0        // GiB
    property real memTotal: 0
    property real cpuTemp: 0        // °C
    property real igpu: 0           // 0–1
    property string dgpu: "unknown" // active | suspended | absent | unknown
    property real disk: 0           // 0–1

    property var _prev: null

    Timer {
        interval: 2000
        repeat: true
        triggeredOnStart: true
        running: root.active
        onTriggered: if (!sampler.running) sampler.running = true
    }

    Process {
        id: sampler
        command: [Theme.lumenRoot + "/scripts/system-info.sh"]
        stdout: StdioCollector {
            onStreamFinished: {
                const kv = {};
                for (const line of text.split("\n")) {
                    const i = line.indexOf("=");
                    if (i > 0) kv[line.slice(0, i)] = line.slice(i + 1);
                }
                const t = (kv.cpu ?? "").split(" ").map(Number);   // user nice system idle iowait irq softirq steal
                if (t.length >= 4) {
                    const idle = t[3] + (t[4] || 0), total = t.reduce((a, b) => a + b, 0);
                    if (root._prev) {
                        const dt = total - root._prev.total, di = idle - root._prev.idle;
                        root.cpu = dt > 0 ? Math.max(0, 1 - di / dt) : 0;
                    }
                    root._prev = { total, idle };
                }
                root.memTotal = Number(kv.mem_total_kb ?? 0) / 1048576;
                root.memUsed = root.memTotal - Number(kv.mem_available_kb ?? 0) / 1048576;
                root.cpuTemp = Number(kv.cpu_temp_mc ?? 0) / 1000;
                root.igpu = Number(kv.igpu_busy ?? 0) / 100;
                root.dgpu = kv.dgpu ?? "unknown";
                root.disk = Number(kv.disk_used_pct ?? 0) / 100;
            }
        }
    }
}
