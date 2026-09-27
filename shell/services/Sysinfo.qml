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
    property bool islandActive: false   // the island's context card also wants samples
    property bool ribbonActive: false   // the merged Ribbon shows a chip when the system is straining
    // Per-screen views ask here instead of binding the flags above: with two
    // screens, two Bindings on one property overwrite each other (an unmerged
    // bar would switch sampling off for the merged one). Sampling runs while
    // any request stands.   request(who, "detail" | "ribbon" | "")
    property var requests: ({})
    function request(who, level) {
        const r = Object.assign({}, requests);
        if (level) r[who] = level; else delete r[who];
        requests = r;
    }
    readonly property bool wantsDetail: active || islandActive || Object.values(requests).includes("detail")
    readonly property bool wantsRibbon: ribbonActive || Object.values(requests).includes("ribbon")
    // NVIDIA details, only while the dGPU is already awake (nvidia-smi would wake it)
    property real dgpuUtil: -1          // 0–1, -1 unknown
    property real dgpuTemp: -1
    property real dgpuMemUsed: -1       // MiB
    property real dgpuMemTotal: -1
    property real dgpuPower: -1         // W
    property string dgpuName: ""
    property string dgpuDriver: ""
    Process {
        id: nv
        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu,memory.used,memory.total,power.draw,name,driver_version", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim().split(",").map(x => x.trim());
                if (f.length < 7) return;
                root.dgpuUtil = Number(f[0]) / 100; root.dgpuTemp = Number(f[1]);
                root.dgpuMemUsed = Number(f[2]); root.dgpuMemTotal = Number(f[3]);
                root.dgpuPower = Number(f[4]); root.dgpuName = f[5]; root.dgpuDriver = f[6];
            }
        }
    }

    Timer {
        // 2 s while someone is looking at the numbers; 6 s when only the Ribbon
        // is watching for a busy system (and no NVIDIA query then)
        readonly property bool detailed: root.wantsDetail
        interval: detailed ? 2000 : 6000
        repeat: true
        triggeredOnStart: true
        running: detailed || root.wantsRibbon
        onTriggered: {
            if (!sampler.running) sampler.running = true;
            if (detailed && root.dgpu === "active" && !nv.running) nv.running = true;
        }
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

    // Dev only (LUMEN_DEV): who is asking for samples, and what the totals
    // come out as. The multi-screen fix is invisible from the outside — with
    // two screens the bug was one sidebar closing switching sampling off for
    // the other — so it needs a way to be looked at.
    IpcHandler {
        target: "sysinfoTest"
        enabled: Quickshell.env("LUMEN_DEV") === "1"
        function state(): string {
            return JSON.stringify({
                requests: root.requests,
                wantsDetail: root.wantsDetail,
                wantsRibbon: root.wantsRibbon,
                sampling: root.wantsDetail || root.wantsRibbon,
            });
        }
        function clear(): void { root.requests = ({}); }
    }
}
