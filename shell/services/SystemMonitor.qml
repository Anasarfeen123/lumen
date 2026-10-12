pragma Singleton
// Lumen Monitor's data (the app is shell/monitor.qml, Ctrl+Shift+Esc): one
// long-running scripts/monitor.py stream while the app is open — nothing at
// all when it isn't. Keeps a few minutes of history for the graphs, groups
// processes the way you think of them (apps with windows · background · system),
// and runs the actions (end, suspend, priority, startup, services).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    readonly property string script: Theme.lumenRoot + "/scripts/monitor.py"
    property bool active: false           // the app is open
    property bool paused: false
    property real interval: 1.0            // seconds
    readonly property int keep: 300        // samples of history per series

    // ── static facts ──
    property var info: ({})
    Process {
        running: root.active
        command: [root.script, "static"]
        stdout: StdioCollector { onStreamFinished: { try { root.info = JSON.parse(text); } catch (e) {} } }
    }

    // ── the stream ──
    property var s: ({})                   // the latest sample
    property int samples: 0
    property var pinfo: ({})               // pid → { cmd, exe, user, comm }
    Process {
        id: stream
        running: root.active && !root.paused
        command: [root.script, "stream", "--interval", String(root.interval)]
        stdout: SplitParser {
            splitMarker: "\n"
            onRead: line => { try { root.ingest(JSON.parse(line)); } catch (e) {} }
        }
    }
    onIntervalChanged: if (stream.running) { stream.running = false; restart.restart(); }
    Timer { id: restart; interval: 50; onTriggered: stream.running = Qt.binding(() => root.active && !root.paused) }

    // History: name → array of numbers (oldest first)
    property var hist: ({})
    property int histVersion: 0            // bumps each sample: graphs repaint
    function push(name, v) {
        const a = hist[name] ?? [];
        a.push(v ?? 0);
        if (a.length > keep) a.splice(0, a.length - keep);
        hist[name] = a;
    }
    // A copy: handing out the same array would not tell graphs it changed
    function series(name) { histVersion; return (hist[name] ?? []).slice(); }

    // Values that arrive every few samples, kept between them
    property var temps: []
    property var battery: null
    property var fs: []
    function ingest(x) {
        // process details arrive once; forget the departed now and then
        const pi = pinfo;
        for (const k in x.pinfo ?? {}) pi[k] = x.pinfo[k];
        if (samples % 30 === 0) {
            const live = new Set((x.procs ?? []).map(r => String(r[0])));
            for (const k in pi) if (!live.has(k)) delete pi[k];
        }
        pinfo = pi;
        if (x.temps) temps = x.temps;
        if (x.battery) battery = x.battery;
        if (x.fs) fs = x.fs;

        push("cpu", x.cpu);
        (x.cores ?? []).forEach((v, i) => push("core" + i, v));
        const m = x.mem ?? {};
        push("mem", m.total ? 100 * (m.total - m.available) / m.total : 0);
        push("swap", m.swapTotal ? 100 * (m.swapTotal - m.swapFree) / m.swapTotal : 0);
        for (const d in x.disks ?? {}) { push("disk:" + d, x.disks[d].active); push("diskR:" + d, x.disks[d].read); push("diskW:" + d, x.disks[d].write); }
        for (const n in x.net ?? {}) { push("rx:" + n, x.net[n].rx); push("tx:" + n, x.net[n].tx); }
        (x.gpus ?? []).forEach(g => push("gpu:" + g.card, g.util ?? 0));
        if (battery) push("battery", battery.watts);
        s = x;
        samples++;
        histVersion++;
    }
    onActiveChanged: if (!active) { hist = ({}); samples = 0; s = ({}); }

    // ── processes ──
    readonly property var cols: ({ pid: 0, ppid: 1, name: 2, uid: 3, state: 4, nice: 5, threads: 6, start: 7, cpu: 8, mem: 9, rss: 10, rd: 11, wr: 12, kernel: 13 })
    function row(r) {
        const i = pinfo[String(r[0])] ?? {};
        return { pid: r[0], ppid: r[1], name: r[2], uid: r[3], state: r[4], nice: r[5], threads: r[6], start: r[7],
                 cpu: r[8], mem: r[9], rss: r[10], rd: r[11], wr: r[12], kernel: r[13] === 1,
                 cmd: i.cmd ?? "", exe: i.exe ?? "", user: i.user ?? String(r[3]), comm: i.comm ?? r[2] };
    }
    readonly property var procs: (s.procs ?? []).map(r => row(r))
    readonly property int uid: info.uid ?? -1

    // Apps: each process with a window, and everything below it (a browser's
    // tabs are its children). Background: your other processes. System: the rest.
    readonly property var groups: {
        const byPid = {}, kids = {};
        for (const p of procs) { byPid[p.pid] = p; (kids[p.ppid] = kids[p.ppid] ?? []).push(p.pid); }
        const wins = s.windows ?? {};
        const taken = new Set(), apps = [];
        const winPids = Object.keys(wins).map(Number).filter(pid => byPid[pid]);
        // A window process inside another window's tree belongs to that app
        const isUnder = (pid, roots) => { let q = byPid[pid]?.ppid; let guard = 0; while (q && q > 1 && guard++ < 64) { if (roots.has(q)) return true; q = byPid[q]?.ppid; } return false; };
        const rootSet = new Set(winPids);
        for (const pid of winPids) {
            if (isUnder(pid, rootSet)) continue;
            const members = [];
            const stack = [pid];
            while (stack.length) {
                const x = stack.pop();
                if (taken.has(x) || !byPid[x]) continue;
                taken.add(x); members.push(byPid[x]);
                for (const k of kids[x] ?? []) stack.push(k);
            }
            const w = wins[String(pid)];
            apps.push(group("app:" + pid, prettyClass(w.class) || byPid[pid].name, w.title, members, w.class, pid));
        }
        const bg = [], sys = [];
        for (const p of procs) {
            if (taken.has(p.pid)) continue;
            if (p.uid === root.uid && !p.kernel) bg.push(group("p:" + p.pid, p.name, p.cmd, [p], "", p.pid));
            else sys.push(group("p:" + p.pid, p.name, p.cmd, [p], "", p.pid));
        }
        return { apps, background: bg, system: sys };
    }
    function group(key, name, sub, members, cls, pid) {
        let cpu = 0, mem = 0, rd = 0, wr = 0, threads = 0, suspended = 0;
        for (const m of members) { cpu += m.cpu; mem += m.mem; rd += m.rd; wr += m.wr; threads += m.threads; if (m.state === "T") suspended++; }
        return { key, name, sub, cls, pid, members, count: members.length, cpu, mem, rd, wr, threads,
                 suspended: suspended > 0 && suspended === members.length, user: members[0]?.user ?? "", kernel: members[0]?.kernel ?? false };
    }
    function prettyClass(c) {
        if (!c) return "";
        const e = DesktopEntries.heuristicLookup(c);
        if (e?.name) return e.name;
        const last = c.split(".").pop();
        return last.charAt(0).toUpperCase() + last.slice(1);
    }
    function iconFor(g) {
        const e = g.cls ? DesktopEntries.heuristicLookup(g.cls) : DesktopEntries.heuristicLookup(g.members?.[0]?.comm ?? "");
        return e?.icon ? Quickshell.iconPath(e.icon, true) : "";
    }

    // ── formatting ──
    function bytes(b, dec) {
        if (b === null || b === undefined) return "–";
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0, v = Math.abs(b);
        while (v >= 1024 && i < u.length - 1) { v /= 1024; i++; }
        return (i === 0 ? Math.round(v) : v.toFixed(dec ?? (v < 10 ? 1 : 0))) + " " + u[i];
    }
    function rate(b) { return b > 0 ? bytes(b) + "/s" : "0"; }
    function bits(b) {
        const v = b * 8, u = ["bps", "Kbps", "Mbps", "Gbps"];
        let i = 0, x = v;
        while (x >= 1000 && i < u.length - 1) { x /= 1000; i++; }
        return (i === 0 ? Math.round(x) : x.toFixed(x < 10 ? 1 : 0)) + " " + u[i];
    }
    function duration(sec) {
        sec = Math.floor(sec);
        const d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60);
        return d ? d + "d " + h + "h " + m + "m" : h ? h + "h " + m + "m" : m + "m " + (sec % 60) + "s";
    }
    function stateName(st) { return ({ R: "Running", S: "Sleeping", D: "Waiting on disk", T: "Suspended", t: "Traced", Z: "Zombie", I: "Idle" })[st] ?? st; }

    // ── actions ──
    signal acted(bool ok, string message)
    function act(args, okMsg) {
        actProc.okMsg = okMsg ?? "";
        actProc.command = [script].concat(args.map(String));
        actProc.running = true;
    }
    Process {
        id: actProc
        property string okMsg: ""
        stdout: StdioCollector {
            onStreamFinished: {
                let r = {}; try { r = JSON.parse(text); } catch (e) {}
                root.acted(r.ok !== false, r.ok === false ? (r.error || "Didn't work") : actProc.okMsg);
                if (root.startupLoaded) root.loadStartup();
                if (root.servicesLoaded) root.loadServices();
            }
        }
    }
    function endTask(g, force) { act(["signal", g.pid, force ? "KILL" : "TERM", "--tree"], (force ? "Forced " : "Ended ") + g.name); }
    function suspend(g, on) { act(["signal", g.pid, on ? "STOP" : "CONT", "--tree"], (on ? "Suspended " : "Resumed ") + g.name); }
    function renice(pid, n) { act(["renice", pid, n], "Priority changed"); }

    property var detail: null
    function loadDetail(pid) { detailProc.command = [script, "detail", String(pid)]; detailProc.running = true; }
    Process { id: detailProc; stdout: StdioCollector { onStreamFinished: { try { root.detail = JSON.parse(text); } catch (e) {} } } }

    property var startup: []
    property bool startupLoaded: false
    function loadStartup() { startupLoaded = true; if (!startupProc.running) startupProc.running = true; }
    Process { id: startupProc; command: [root.script, "startup"]; stdout: StdioCollector { onStreamFinished: { try { root.startup = JSON.parse(text); } catch (e) {} } } }
    function setStartup(item, on) { act(["startup-set", item.kind, item.id, on ? "on" : "off"], item.name + (on ? " starts at login" : " won't start at login")); }

    property var services: ({ user: [], system: [] })
    property bool servicesLoaded: false
    function loadServices() { servicesLoaded = true; if (!servicesProc.running) servicesProc.running = true; }
    Process { id: servicesProc; command: [root.script, "services"]; stdout: StdioCollector { onStreamFinished: { try { root.services = JSON.parse(text); } catch (e) {} } } }
    function service(unit, action) { act(["service", unit, action], unit + ": " + action); }
}
