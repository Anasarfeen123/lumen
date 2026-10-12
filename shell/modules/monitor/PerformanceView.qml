// Performance: every resource down the left with a live sparkline — CPU,
// memory, each disk, each network link, each GPU, the battery — and the
// chosen one in depth on the right: a large graph and the numbers behind it.
import QtQuick
import QtQuick.Controls.Basic as QQC
import Quickshell
import qs.theme
import qs.components
import qs.services

Item {
    id: view
    readonly property var smp: SystemMonitor.s
    readonly property var inf: SystemMonitor.info
    property string pick: "cpu"
    property bool perCore: false

    readonly property var resources: {
        SystemMonitor.samples;
        const S = view.smp, I = view.inf;
        const r = [{ id: "cpu", icon: "memory", title: "CPU", series: "cpu", max: 100, value: Math.round(S.cpu ?? 0) + "%", sub: avgMhz() ? (avgMhz() / 1000).toFixed(2) + " GHz" : "" }];
        const m = S.mem ?? {};
        r.push({ id: "mem", icon: "memory_alt", title: "Memory", series: "mem", max: 100,
                 value: SystemMonitor.bytes(m.total - m.available, 1) + " / " + SystemMonitor.bytes(m.total, 0),
                 sub: m.total ? Math.round(100 * (m.total - m.available) / m.total) + "%" : "" });
        for (const d of I.disks ?? []) {
            const x = (S.disks ?? {})[d.dev];
            if (!x) continue;
            r.push({ id: "disk:" + d.dev, icon: d.kind === "zram" ? "compress" : "hard_drive", title: d.kind === "zram" ? "Swap (zram)" : "Disk · " + d.dev,
                     series: "disk:" + d.dev, max: 100, value: Math.round(x.active) + "%", sub: d.kind === "zram" ? "in RAM" : d.kind.toUpperCase(), disk: d });
        }
        for (const n in S.net ?? {}) {
            const x = S.net[n];
            if (x.kind === "virtual" || (!x.up && !x.rx && !x.tx)) continue;
            r.push({ id: "net:" + n, icon: x.kind === "wifi" ? "wifi" : x.kind === "vpn" ? "vpn_lock" : x.kind === "phone" ? "smartphone" : "lan",
                     title: x.kind === "wifi" ? "Wi-Fi" : x.kind === "vpn" ? "VPN · " + n : x.kind === "phone" ? "Phone · " + n : "Ethernet · " + n,
                     series: "rx:" + n, series2: "tx:" + n, max: 0, value: "↓ " + SystemMonitor.bits(x.rx) + "  ↑ " + SystemMonitor.bits(x.tx), sub: x.ssid ?? "", net: n });
        }
        for (const g of S.gpus ?? []) {
            const awake = g.state === "active";
            r.push({ id: "gpu:" + g.card, icon: "developer_board", title: "GPU · " + (g.kind === "amd" ? "Radeon" : g.kind === "nvidia" ? "NVIDIA" : g.kind),
                     series: "gpu:" + g.card, max: 100, value: awake && g.util !== undefined && g.util !== null ? Math.round(g.util) + "%" : g.state === "suspended" ? "Asleep" : g.state === "error" ? "Stuck awake" : "–",
                     sub: g.temp ? Math.round(g.temp) + " °C" : "", gpu: g });
        }
        if (SystemMonitor.battery) {
            const b = SystemMonitor.battery;
            r.push({ id: "battery", icon: b.status === "Charging" ? "battery_charging_full" : "battery_full", title: "Battery", series: "battery", max: 0,
                     value: b.pct + "%", sub: b.watts ? b.watts.toFixed(1) + " W" : b.status });
        }
        return r;
    }
    readonly property var cur: resources.find(r => r.id === pick) ?? resources[0]
    function avgMhz() { const f = (view.smp.mhz ?? []).filter(x => x); return f.length ? f.reduce((a, b) => a + b, 0) / f.length : 0; }
    function temp(match) { const t = SystemMonitor.temps.find(x => match.test(x.chip + " " + x.label)); return t ? Math.round(t.c) + " °C" : "–"; }

    // ── the list ──
    ListView {
        id: side
        width: 270
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left; leftMargin: Theme.space.s3 }
        clip: true
        spacing: 4
        model: view.resources
        boundsBehavior: Flickable.StopAtBounds
        delegate: HoverTarget {
            id: res
            required property var modelData
            readonly property bool on: view.cur?.id === modelData.id
            width: side.width; height: 74; radius: Theme.radius.md
            onClicked: view.pick = modelData.id
            Rectangle { anchors.fill: parent; radius: parent.radius; z: -1
                        color: res.on ? Theme.withAlpha(Theme.accent, 0.12) : res.containsMouse ? Theme.withAlpha(Theme.text, 0.04) : "transparent"
                        border.width: res.on ? 1 : 0; border.color: Theme.withAlpha(Theme.accent, 0.35) }
            Graph {
                id: spark
                anchors { left: parent.left; leftMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                width: 86; height: 54
                values: SystemMonitor.series(res.modelData.series)
                values2: res.modelData.series2 ? SystemMonitor.series(res.modelData.series2) : []
                max: res.modelData.max
                points: 40; grid: false; lineWidth: 1.2
                color: res.on ? Theme.accent : Theme.textSecondary
            }
            Column {
                anchors { left: spark.right; leftMargin: Theme.space.s3; right: parent.right; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                spacing: 1
                LText { width: parent.width; elide: Text.ElideRight; role: "bodyStrong"; text: res.modelData.title }
                LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textSecondary; text: res.modelData.value }
                LText { width: parent.width; elide: Text.ElideRight; role: "caption"; color: Theme.textMuted; text: res.modelData.sub; visible: text !== "" }
            }
        }
    }

    // ── the chosen one ──
    QQC.ScrollView {
        anchors { top: parent.top; bottom: parent.bottom; left: side.right; right: parent.right; leftMargin: Theme.space.s5; rightMargin: Theme.space.s4 }
        contentWidth: availableWidth
        Column {
            id: main
            width: parent.width
            spacing: Theme.space.s3

            Item {
                width: parent.width; height: 40
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    LText { role: "title"; font.pixelSize: 22; text: view.cur?.title ?? "" }
                }
                LText {
                    anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                    width: Math.min(implicitWidth, parent.width * 0.6); elide: Text.ElideRight
                    role: "body"; color: Theme.textSecondary
                    text: view.cur?.id === "cpu" ? (view.inf.cpu?.model ?? "")
                        : view.cur?.disk ? view.cur.disk.model
                        : view.cur?.gpu ? view.cur.gpu.name
                        : view.cur?.id === "battery" ? (SystemMonitor.battery?.model ?? "")
                        : view.cur?.net ? (view.smp.net?.[view.cur.net]?.mac ?? "") : ""
                }
            }

            // Big graph — or one per core
            Row {
                visible: view.cur?.id === "cpu"
                spacing: Theme.space.s2
                Segmented {
                    width: 220
                    options: [{ id: "all", label: "Overall" }, { id: "cores", label: "Each thread" }]
                    current: view.perCore ? "cores" : "all"
                    onPicked: id => view.perCore = id === "cores"
                }
            }
            Item {
                width: parent.width
                height: view.cur?.id === "cpu" && view.perCore ? coresGrid.height : 300
                LText { visible: !(view.cur?.id === "cpu" && view.perCore); anchors { left: parent.left; bottom: big.top; bottomMargin: 2 }
                        role: "caption"; color: Theme.textMuted
                        text: view.cur?.series2 ? "Receive (solid) · Send (dashed) · last " + Math.round(60 * SystemMonitor.interval) + " s"
                            : view.cur?.max === 100 ? "% · last " + Math.round(60 * SystemMonitor.interval) + " s" : "last " + Math.round(60 * SystemMonitor.interval) + " s" }
                Graph {
                    id: big
                    visible: !(view.cur?.id === "cpu" && view.perCore)
                    anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                    height: 280
                    values: SystemMonitor.series(view.cur?.series ?? "")
                    values2: view.cur?.series2 ? SystemMonitor.series(view.cur.series2) : []
                    max: view.cur?.max ?? 100
                    points: 60
                }
                Grid {
                    id: coresGrid
                    visible: view.cur?.id === "cpu" && view.perCore
                    width: parent.width
                    columns: (view.smp.cores ?? []).length > 8 ? 4 : 2
                    spacing: Theme.space.s2
                    Repeater {
                        model: (view.smp.cores ?? []).length
                        delegate: Item {
                            required property int index
                            width: (coresGrid.width - (coresGrid.columns - 1) * coresGrid.spacing) / coresGrid.columns
                            height: 92
                            Graph { anchors.fill: parent; values: SystemMonitor.series("core" + parent.index); max: 100; points: 60; lineWidth: 1.2 }
                            LText { x: 6; y: 4; role: "caption"; color: Theme.textMuted
                                    text: "Thread " + parent.index + " · " + Math.round(view.smp.cores?.[parent.index] ?? 0) + "% · " + ((view.smp.mhz?.[parent.index] ?? 0) / 1000).toFixed(2) + " GHz" }
                        }
                    }
                }
            }

            // Memory composition
            Column {
                visible: view.cur?.id === "mem"
                width: parent.width; spacing: 6
                readonly property var m: view.smp.mem ?? {}
                LText { role: "caption"; color: Theme.textMuted; text: "COMPOSITION"; font.letterSpacing: 1 }
                Rectangle {
                    width: parent.width; height: 26; radius: Theme.radius.sm; clip: true
                    color: Theme.withAlpha(Theme.text, 0.05); border.width: 1; border.color: Theme.border
                    readonly property var m: parent.m
                    readonly property real inUse: (m.total ?? 0) - (m.available ?? 0)
                    Row {
                        anchors.fill: parent
                        Rectangle { height: parent.height; color: Theme.withAlpha(Theme.accent, 0.75); width: parent.width * (parent.parent.inUse / Math.max(1, parent.parent.m.total)) }
                        Rectangle { height: parent.height; color: Theme.withAlpha(Theme.warning, 0.45); width: parent.width * ((parent.parent.m.dirty ?? 0) / Math.max(1, parent.parent.m.total)) }
                        Rectangle { height: parent.height; color: Theme.withAlpha(Theme.accent, 0.25); width: parent.width * (Math.max(0, (parent.parent.m.cached ?? 0)) / Math.max(1, parent.parent.m.total)) }
                    }
                }
                Row {
                    spacing: Theme.space.s4
                    Legend { tone: Theme.withAlpha(Theme.accent, 0.75); label: "In use" }
                    Legend { tone: Theme.withAlpha(Theme.warning, 0.45); label: "Waiting to be written" }
                    Legend { tone: Theme.withAlpha(Theme.accent, 0.25); label: "Cached (given back when needed)" }
                    Legend { tone: Theme.withAlpha(Theme.text, 0.05); label: "Free" }
                }
            }

            // Filesystems on this disk
            Column {
                visible: !!view.cur?.disk && view.cur.disk.kind !== "zram"
                width: parent.width; spacing: 6
                LText { role: "caption"; color: Theme.textMuted; text: "SPACE"; font.letterSpacing: 1 }
                Repeater {
                    model: SystemMonitor.fs.filter(f => f.disk === view.cur?.disk?.dev)
                    delegate: Column {
                        required property var modelData
                        width: main.width; spacing: 3
                        Item {
                            width: parent.width; height: 18
                            LText { role: "body"; text: modelData.mount + "  ·  " + modelData.fs }
                            LText { anchors.right: parent.right; role: "caption"; color: Theme.textSecondary
                                    text: SystemMonitor.bytes(modelData.free) + " free of " + SystemMonitor.bytes(modelData.size) }
                        }
                        Rectangle {
                            width: parent.width; height: 8; radius: 4; color: Theme.withAlpha(Theme.text, 0.07)
                            Rectangle { height: parent.height; radius: 4; width: parent.width * modelData.used / modelData.size
                                        color: modelData.used / modelData.size > 0.9 ? Theme.error : Theme.accent }
                        }
                    }
                }
                Row {
                    spacing: Theme.space.s4
                    Graph { width: (main.width - Theme.space.s4) / 2; height: 110; max: 0; points: 60
                            values: SystemMonitor.series("diskR:" + (view.cur?.disk?.dev ?? "")) }
                    Graph { width: (main.width - Theme.space.s4) / 2; height: 110; max: 0; points: 60; color: Theme.warning
                            values: SystemMonitor.series("diskW:" + (view.cur?.disk?.dev ?? "")) }
                }
                Row {
                    spacing: Theme.space.s4
                    LText { width: (main.width - Theme.space.s4) / 2; role: "caption"; color: Theme.textMuted; text: "Read" }
                    LText { width: (main.width - Theme.space.s4) / 2; role: "caption"; color: Theme.textMuted; text: "Write" }
                }
            }

            // A GPU stuck awake: say so, and offer the fix
            Rectangle {
                visible: !!view.cur?.gpu && (view.smp.gpus ?? []).some(g => g.card === view.cur.gpu.card && g.state === "error")
                width: parent.width; height: 64; radius: Theme.radius.md
                color: Theme.withAlpha(Theme.warning, 0.1); border.width: 1; border.color: Theme.withAlpha(Theme.warning, 0.4)
                Row {
                    anchors { left: parent.left; leftMargin: Theme.space.s4; verticalCenter: parent.verticalCenter }
                    spacing: Theme.space.s3
                    LIcon { icon: "battery_alert"; size: 22; color: Theme.warning; anchors.verticalCenter: parent.verticalCenter }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        LText { role: "bodyStrong"; text: "Stuck awake — its power management failed" }
                        LText { role: "caption"; color: Theme.textSecondary; text: "It can't go to sleep, so it uses the battery even when nothing needs it. Fixing asks for your password." }
                    }
                }
                HoverTarget {
                    anchors { right: parent.right; rightMargin: Theme.space.s3; verticalCenter: parent.verticalCenter }
                    width: 92; height: 34; radius: 17
                    onClicked: Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen-shell-ipc", "gpu", "fix"])   // the shell checks the result
                    Rectangle { anchors.fill: parent; radius: 17; z: -1; color: Theme.accent }
                    LText { anchors.centerIn: parent; role: "bodyStrong"; color: Theme.onAccent; text: "Fix" }
                }
            }

            // The numbers
            Flow {
                width: parent.width
                spacing: Theme.space.s2
                Repeater {
                    model: {
                        SystemMonitor.samples;
                        const S = view.smp, I = view.inf, c = view.cur;
                        if (!c) return [];
                        if (c.id === "cpu") {
                            const cpuProcs = (S.procs ?? []).length;
                            const threads = (S.procs ?? []).reduce((a, r) => a + r[6], 0);
                            return [["Utilisation", Math.round(S.cpu ?? 0) + "%"], ["Speed", (view.avgMhz() / 1000).toFixed(2) + " GHz"],
                                    ["Max speed", I.cpu?.maxMHz ? (I.cpu.maxMHz / 1000).toFixed(2) + " GHz" : "–"],
                                    ["Temperature", view.temp(/k10temp|coretemp|Tctl|Package/i)],
                                    ["Processes", cpuProcs], ["Threads", threads.toLocaleString()],
                                    ["Cores · threads", (I.cpu?.cores ?? "–") + " · " + (I.cpu?.threads ?? "–")],
                                    ["L1 · L2 · L3", [I.cpu?.caches?.L1d, I.cpu?.caches?.L2, I.cpu?.caches?.L3].filter(x => x).join(" · ")],
                                    ["Load (1·5·15 min)", (S.load ?? []).map(x => x.toFixed(2)).join(" · ")],
                                    ["Virtualisation", I.cpu?.virt === "svm" ? "AMD-V" : I.cpu?.virt === "vmx" ? "VT-x" : "Off"],
                                    ["Up for", S.uptime ? SystemMonitor.duration(S.uptime) : "–"]];
                        }
                        if (c.id === "mem") {
                            const m = S.mem ?? {};
                            return [["In use", SystemMonitor.bytes(m.total - m.available, 1)], ["Available", SystemMonitor.bytes(m.available, 1)],
                                    ["Cached", SystemMonitor.bytes(m.cached, 1)], ["Shared", SystemMonitor.bytes(m.shared, 1)],
                                    ["Committed", SystemMonitor.bytes(m.committed, 1)], ["Free", SystemMonitor.bytes(m.free, 1)],
                                    ["Swap used", SystemMonitor.bytes(m.swapTotal - m.swapFree, 1) + " of " + SystemMonitor.bytes(m.swapTotal, 0)],
                                    ["Total", SystemMonitor.bytes(m.total, 1)]];
                        }
                        if (c.disk) {
                            const x = (S.disks ?? {})[c.disk.dev] ?? {};
                            return [["Active time", Math.round(x.active ?? 0) + "%"], ["Read", SystemMonitor.rate(x.read ?? 0)], ["Write", SystemMonitor.rate(x.write ?? 0)],
                                    ["Read since boot", SystemMonitor.bytes(x.readTotal)], ["Written since boot", SystemMonitor.bytes(x.writeTotal)],
                                    ["Capacity", SystemMonitor.bytes(c.disk.size, 0)], ["Type", c.disk.kind === "zram" ? "Compressed RAM" : c.disk.kind.toUpperCase()],
                                    ["Temperature", c.disk.kind === "nvme" ? view.temp(/nvme.*Composite|nvme/i) : "–"]];
                        }
                        if (c.net) {
                            const x = (S.net ?? {})[c.net] ?? {};
                            return [["Receive", SystemMonitor.bits(x.rx ?? 0)], ["Send", SystemMonitor.bits(x.tx ?? 0)],
                                    ["Received since boot", SystemMonitor.bytes(x.rxTotal)], ["Sent since boot", SystemMonitor.bytes(x.txTotal)],
                                    ["Network", x.ssid ?? c.net], ["IPv4", (x.v4 ?? []).join(", ") || "–"], ["IPv6", (x.v6 ?? []).join(", ") || "–"],
                                    ["Link speed", x.speed ? x.speed + " Mbps" : "–"],
                                    ...(x.signal !== undefined ? [["Signal", x.signal + " dBm · " + (x.signal >= -55 ? "excellent" : x.signal >= -67 ? "good" : x.signal >= -75 ? "fair" : "weak")]] : []),
                                    ...(x.band ? [["Band", x.band]] : []),
                                    ["Hardware address", x.mac ?? "–"]];
                        }
                        if (c.gpu) {
                            const g = (S.gpus ?? []).find(x => x.card === c.gpu.card) ?? c.gpu;
                            const awake = g.state === "active";
                            const st = g.state === "suspended" ? "Asleep (saving power)" : g.state === "error" ? "Power management error — not queried" : g.state === "active" ? "Awake" : g.state;
                            return [["State", st], ["Utilisation", awake && g.util !== null && g.util !== undefined ? Math.round(g.util) + "%" : "–"],
                                    ["Video memory", g.vramUsed ? SystemMonitor.bytes(g.vramUsed, 1) + " of " + SystemMonitor.bytes(g.vramTotal, 1) : "–"],
                                    ["Shared memory", g.gtt ? SystemMonitor.bytes(g.gtt, 1) : "–"], ["Temperature", g.temp ? Math.round(g.temp) + " °C" : "–"],
                                    ["Clock", g.mhz ? Math.round(g.mhz) + " MHz" : "–"], ["Power", g.power ? g.power.toFixed(1) + " W" : "–"],
                                    ["PCI slot", g.slot]];
                        }
                        if (c.id === "battery") {
                            const b = SystemMonitor.battery ?? {};
                            const hours = b.watts > 0.5 && b.energyWh ? (b.status === "Charging" ? ((b.fullWh - b.energyWh) / b.watts) : (b.energyWh / b.watts)) : 0;
                            return [["Charge", b.pct + "%"], ["Status", b.status], ["Power", (b.watts ?? 0).toFixed(1) + " W " + (b.status === "Charging" ? "in" : "out")],
                                    [b.status === "Charging" ? "Full in" : "Left", hours ? SystemMonitor.duration(hours * 3600) : "–"],
                                    ["Energy", (b.energyWh ?? "–") + " of " + (b.fullWh ?? "–") + " Wh"], ["Health", b.health ? b.health + "% of new" : "–"],
                                    ["Charge cycles", b.cycles ?? "–"], ["Charge limit", b.limit ? b.limit + "%" : "Off"]];
                        }
                        return [];
                    }
                    delegate: Rectangle {
                        required property var modelData
                        width: Math.max(150, (main.width - Theme.space.s2 * 3) / 4); height: 58
                        radius: Theme.radius.sm
                        color: Theme.withAlpha(Theme.surfaceElevated, 0.6); border.width: 1; border.color: Theme.border
                        Column {
                            anchors { left: parent.left; right: parent.right; leftMargin: Theme.space.s3; rightMargin: Theme.space.s2; verticalCenter: parent.verticalCenter }
                            LText { role: "caption"; color: Theme.textMuted; text: modelData[0] }
                            LText { width: parent.width; elide: Text.ElideRight; role: "bodyStrong"; font.features: { "tnum": 1 }; text: String(modelData[1]) }
                        }
                    }
                }
            }

            // Sensors (CPU view)
            Column {
                visible: view.cur?.id === "cpu" && SystemMonitor.temps.length > 0
                width: parent.width; spacing: 4
                LText { role: "caption"; color: Theme.textMuted; text: "SENSORS"; font.letterSpacing: 1 }
                Flow {
                    width: parent.width; spacing: Theme.space.s2
                    Repeater {
                        model: SystemMonitor.temps
                        delegate: Rectangle {
                            required property var modelData
                            width: tRow.implicitWidth + 20; height: 28; radius: 14
                            color: Theme.withAlpha(modelData.crit && modelData.c > modelData.crit - 10 ? Theme.error : Theme.text, 0.06)
                            Row { id: tRow; anchors.centerIn: parent; spacing: 6
                                  LText { role: "caption"; color: Theme.textMuted; text: modelData.chip + (modelData.label !== modelData.chip ? " · " + modelData.label : "") }
                                  LText { role: "caption"; text: modelData.c.toFixed(0) + " °C" } }
                        }
                    }
                }
            }
        }
    }
    component Legend: Row {
        property color tone
        property string label
        spacing: 5
        Rectangle { width: 10; height: 10; radius: 3; color: parent.tone; border.width: 1; border.color: Theme.border; anchors.verticalCenter: parent.verticalCenter }
        LText { role: "caption"; color: Theme.textSecondary; text: parent.label }
    }
}
