pragma Singleton
// Halo's watchful doctor. A cheap look at the system every minute on battery
// (two on the charger) — scripts/monitor.py doctor — and Halo speaks up only
// when something deserves it, with a one-tap fix:
//
//   a hog        one app busy for three looks in a row (on battery it's what
//                drains it: "Brave · 32 tabs · 2.4 GB — about 1 h 10 m left")
//   the drain    the battery falling much faster than usual
//   a call       the battery may not last the call
//   memory       nearly full, and who holds it
//   heat         running hot
//   disk         almost full
//   breakage     a failed background service, or a program that crashed
//
// Each finding is said once, then rests (an hour or more); "Not now" rests it
// three hours, "Never for <app>" for good (Settings → Halo lists them).
// Terminals (your builds), games and Lumen itself are never called hogs.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    property bool devEnabled: false
    readonly property bool enabled: (Persist.automates || devEnabled) && (Persist.data.haloDoctor ?? true)
    readonly property var ignore: Persist.data.haloDoctorIgnore ?? []

    property var last: null             // the latest look
    property var looks: []              // the last few, oldest first
    property var findings: []           // what's wrong right now: [{ id, card, time }]
    readonly property bool worried: findings.some(f => Date.now() - f.time < 15 * 60000)
    property var rest: ({})             // id → don't say again before (ms)
    property bool replyNext: false      // "how's my computer?": answer even if all is well

    Timer {
        interval: Battery.available && !Battery.pluggedIn ? 60000 : 120000
        repeat: true; triggeredOnStart: true
        running: root.enabled
        onTriggered: root.look()
    }
    function look() { if (!probe.running) probe.running = true; }
    function checkNow(reply) { replyNext = !!reply; look(); }
    Process {
        id: probe
        command: [Theme.lumenRoot + "/scripts/monitor.py", "doctor"]
        stdout: StdioCollector { onStreamFinished: { let d; try { d = JSON.parse(text); } catch (e) { return; } root.ingest(d); } }
    }

    // ── helpers ──
    readonly property var exempt: /^(kitty|foot|alacritty|wezterm.*|konsole|gnome-terminal.*|ptyxis|xterm|lumen|qs|quickshell|hyprland|xdg-desktop-portal.*|pipewire.*|wireplumber|ollama)$/i
    function bytes(b) { return b >= 1073741824 ? (b / 1073741824).toFixed(1) + " GB" : Math.round(b / 1048576) + " MB"; }
    function pct(cores, ncpu) { return Math.round(100 * cores / Math.max(1, ncpu)); }
    function about(g) {
        return [g.tabs > 1 ? "about " + g.tabs + " tabs" : "", bytes(g.mem) + " of memory",
                pct(g.cores, last?.ncpu ?? 8) + "% of the processor"].filter(x => x).join(" · ");
    }
    function canSay(id) { return (rest[id] ?? 0) < Date.now(); }
    function rested(id, ms) { const r = Object.assign({}, rest); r[id] = Date.now() + ms; rest = r; }
    function notNow(id) { return { label: "Not now", icon: "snooze", run: () => root.rested(id, 3 * 3600000) }; }
    function closeApp(g) {
        return { label: "Close " + g.name, icon: "close", run: () => {
            Quickshell.execDetached([Theme.lumenRoot + "/scripts/monitor.py", "signal", String(g.pid), "TERM", "--tree"]);
            Halo.say({ key: "doctor:closed", icon: "check", title: g.name + " is closing", text: g.tabs > 1 ? "It'll offer to bring your tabs back next time." : "",
                       tone: "happy", level: "asked", duration: 3000, speak: false });
        } };
    }
    function never(g) {
        return { label: "Never for " + g.name, icon: "visibility_off", run: () => { Persist.data.haloDoctorIgnore = root.ignore.concat([g.name]); } };
    }
    function askHalo(question) { return { label: "Ask " + Halo.name, icon: "auto_awesome", run: () => { Ai.show(); Ai.send(question); } }; }
    function powerSaver() {
        return Power.saver ? null : { label: "Battery saver", icon: "energy_savings_leaf", run: () => Power.saverOn() };
    }
    function found(id, card, ms) {
        card.key = "doctor:" + id;
        card.tone = card.tone ?? "concerned";
        card.actions = (card.actions ?? []).filter(a => a);
        findings = findings.filter(f => f.id !== id).concat([{ id, card, time: Date.now() }]);
        if (!canSay(id)) return;
        rested(id, ms ?? 3600000);
        Halo.say(card);
    }

    // ── a look ──
    function ingest(d) {
        last = d;
        looks = looks.concat([d]).slice(-5);
        findings = [];
        const onBattery = d.battery && Battery.available && !Battery.pluggedIn;
        const gaming = GameMode.on || Context.kind === "game";
        const steady = looks.filter(l => l.interval > 30).slice(-3);
        const apps = (d.apps ?? []).filter(g => !exempt.test(g.name) && !ignore.includes(g.name));
        const busiest = apps[0] ?? null;

        // a hog: busy for three looks in a row
        const limit = onBattery ? 0.8 : 2.0;
        if (steady.length === 3 && !gaming) {
            for (const g of apps) {
                const all = steady.every(l => (l.apps ?? []).some(x => x.name === g.name && x.cores >= limit));
                if (!all) continue;
                const mins = Math.round(steady.reduce((s, l) => s + l.interval, 0) / 60);
                found("hog:" + g.name, {
                    icon: "speed",
                    title: g.name + " has been working hard for " + mins + " min",
                    text: about(g) + (onBattery && Battery.forecastText ? ". That's draining the battery — about " + Battery.forecastText + " left." : "."),
                    level: "important",
                    actions: [g.window ? closeApp(g) : null, askHalo("Why would " + g.name + " use " + pct(g.cores, d.ncpu) + "% CPU for " + mins + " minutes on Fedora, and how do I calm it down?"),
                              notNow("hog:" + g.name), never(g)]
                }, 2 * 3600000);
                break;
            }
        }

        // the drain: much faster than usual
        if (onBattery && Battery.usualRate > 0 && Battery.ratePerHour > 1.6 * Battery.usualRate && Battery.forecastMin > 0 && Battery.forecastMin < 150)
            found("drain", {
                icon: "battery_alert",
                title: "The battery is draining faster than usual",
                text: "About " + Battery.forecastText + " left" + (busiest && busiest.cores > 0.3 ? " — " + busiest.name + " is the busiest (" + about(busiest) + ")." : "."),
                level: "important",
                actions: [powerSaver(), { label: "Dim the screen", icon: "brightness_low", run: () => Brightness.set(Math.min(Brightness.value ?? 0.4, 0.35)) },
                          busiest && busiest.window && busiest.cores > 0.3 ? closeApp(busiest) : null, notNow("drain")]
            }, 3 * 3600000);

        // a call that may outlast the battery
        if (Meeting.live && onBattery && Battery.forecastMin > 0 && Battery.forecastMin < 25)
            found("call", { icon: "battery_alert", title: "Plug in soon — about " + Math.round(Battery.forecastMin) + " min left",
                            text: "Your call on " + Meeting.appName + " may outlast the battery.", level: "important", throughQuiet: true, speak: false,
                            actions: [powerSaver()] }, 20 * 60000);

        // memory nearly full
        const m = d.mem ?? {};
        const memLow = m.total > 0 && m.available / m.total < 0.10 && m.swapTotal > 0 && (m.swapTotal - m.swapFree) / m.swapTotal > 0.5;
        const memHeavy = [...(d.apps ?? [])].sort((a, b) => b.mem - a.mem)[0];
        if (memLow && looks.length >= 2 && (looks[looks.length - 2].mem?.available ?? m.total) / m.total < 0.12)
            found("memory", {
                icon: "memory", title: "Memory is nearly full — " + Math.round(100 * m.available / m.total) + "% free",
                text: memHeavy ? memHeavy.name + " holds " + bytes(memHeavy.mem) + (memHeavy.tabs > 1 ? " across about " + memHeavy.tabs + " tabs" : "") + ". Things may slow down." : "Things may slow down.",
                level: "important",
                actions: [memHeavy && memHeavy.window && !exempt.test(memHeavy.name) ? closeApp(memHeavy) : null,
                          { label: "See what's using it", icon: "monitor_heart", run: () => Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen-monitor", "processes"]) }, notNow("memory")]
            });

        // heat
        const hot = (d.temp ?? 0) >= 90 && looks.length >= 2 && (looks[looks.length - 2].temp ?? 0) >= 88;
        if (hot)
            found("heat", { icon: "device_thermostat", title: "Running hot — " + Math.round(d.temp) + " °C",
                            text: (busiest && busiest.cores > 0.5 ? busiest.name + " is the busiest. " : "") + "Battery saver cools it down; so does a hard, flat surface.",
                            level: "important", actions: [powerSaver(), notNow("heat")] });

        // disk almost full
        const seen = {}, disks = (d.fs ?? []).filter(f => { const k = f.size + ":" + f.free; if (seen[k]) return false; seen[k] = true; return true; });
        const tight = disks.find(f => f.free < Math.max(5 * 1073741824, 0.03 * f.size));
        if (tight)
            found("disk", { icon: "hard_drive", title: "Disk space is low — " + bytes(tight.free) + " left",
                            text: "On " + (tight.mount === "/" ? "the system drive" : tight.mount.replace(Quickshell.env("HOME"), "~")) + ". Updates and downloads may fail.",
                            level: "important",
                            actions: [askHalo("My disk is almost full (" + bytes(tight.free) + " left on " + tight.mount + "). What can I safely clean on Fedora? Give me the commands, safest first."), notNow("disk")] }, 24 * 3600000);

        // a background service failed
        for (const u of d.failed ?? [])
            found("failed:" + u, { icon: "error", title: "A background service stopped: " + u.replace(/\.service$/, ""),
                                   text: "It failed and didn't come back by itself.", level: "important",
                                   actions: [{ label: "Restart it", icon: "restart_alt", run: () => SystemMonitor.service(u, "restart") },
                                             askHalo("The user service " + u + " failed on my Fedora system. How do I find out why (journalctl) and fix it?"), notNow("failed:" + u)] }, 24 * 3600000);

        // something crashed since the last look
        for (const c of d.crashes ?? []) {
            const name = crashNames[c.exe] ?? (c.mine ? c.exe : "");
            if (!name) continue;
            const n = (crashCount[c.exe] = (crashCount[c.exe] ?? 0) + 1);
            found("crash:" + c.exe, {
                icon: "healing", title: name + (n > 1 ? " crashed again (" + n + " times today)" : " crashed"),
                text: (restarts.includes(c.exe) ? "It restarted by itself. " : "") + (n > 1 ? "If it keeps happening, an update usually fixes it." : ""),
                level: n > 1 || !restarts.includes(c.exe) ? "important" : "chatter", tone: "concerned",
                actions: [HaloExtras.units[c.exe] ? { label: "Restart it", icon: "restart_alt", run: () => HaloExtras.restartUnit(HaloExtras.units[c.exe], () => Halo.say({ key: "doctor:fixed", icon: "healing", title: name + " restarted", text: "", tone: "happy", level: "asked", duration: 3000, speak: false })) } : null,
                          askHalo(c.exe + " crashed " + n + " time(s) today with signal " + c.sig + " on Fedora (I can run coredumpctl). What usually causes this and how do I fix it?")]
            }, n > 2 ? 6 * 3600000 : 0);
        }

        // "how's my computer?"
        if (replyNext) {
            replyNext = false;
            if (findings.length) for (const f of findings) Halo.say(Object.assign({}, f.card, { level: "asked" }));
            else Halo.say({ key: "doctor:ok", icon: "verified", tone: "happy", level: "asked", title: "All good",
                            text: [Math.round(100 * (d.cpu ?? 0) / Math.max(1, d.ncpu)) + "% busy",
                                   m.total ? Math.round(100 * m.available / m.total) + "% memory free" : "",
                                   d.temp ? Math.round(d.temp) + " °C" : "",
                                   Battery.available ? (Battery.pluggedIn ? "charging · " + Math.round(Battery.percentage * 100) + "%" : (Battery.forecastText ? Battery.forecastText + " of battery left" : Math.round(Battery.percentage * 100) + "% battery")) : "",
                                   busiest && busiest.cores > 0.2 ? "busiest: " + busiest.name : ""].filter(x => x).join(" · ") });
        }
    }
    property var crashCount: ({})
    readonly property var crashNames: ({ wireplumber: "The audio service (WirePlumber)", pipewire: "Audio (PipeWire)", "pipewire-pulse": "Audio (PipeWire)",
                                         bluetoothd: "Bluetooth", NetworkManager: "Networking", Hyprland: "Hyprland", qs: "Lumen's shell", quickshell: "Lumen's shell",
                                         "xdg-desktop-portal": "The desktop portal", kwalletd6: "KWallet", hypridle: "The idle handler" })
    readonly property var restarts: ["wireplumber", "pipewire", "pipewire-pulse", "bluetoothd", "NetworkManager", "xdg-desktop-portal", "qs", "quickshell"]
    // A new day starts the crash count over
    Timer { interval: 3600000; repeat: true; running: true; property string day: ""
            onTriggered: { const k = new Date().toDateString(); if (day && day !== k) root.crashCount = ({}); day = k; } }

    IpcHandler {
        target: "doctor"
        function check(): void { root.checkNow(true); }
        function state(): string { return JSON.stringify({ findings: root.findings.map(f => f.card.title), last: root.last }); }
        // Dev only (LUMEN_DEV): feed a made-up look
        function feed(json: string): void { if (Quickshell.env("LUMEN_DEV") === "1") { root.rest = ({}); try { root.ingest(JSON.parse(json)); } catch (e) {} } }
        function enable(): void { if (Quickshell.env("LUMEN_DEV") === "1") root.devEnabled = true; }
    }
}
