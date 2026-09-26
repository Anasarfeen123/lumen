pragma Singleton
// Screen time & focus, stored on this machine only (DESIGN.md §31).
//
// Every 5 s the main shell adds 5 s to the focused app — but not while you're
// idle (2 min, video/caffeine inhibitors respected), the screen is locked, or
// the overview is open. Focus-mode time and finished Pomodoro rounds are
// counted too. One small file per day:
//   ~/.local/state/lumen/screentime/<YYYY-MM-DD>.json
//     { date, total, apps: { "<app id>": seconds }, focus: seconds, rounds: n }
// Written at most once a minute and on exit; files older than 60 days go to
// the trash. Settings → Planner card: "Record screen time" / "Clear history".
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs.theme

Singleton {
    id: root
    readonly property bool enabled: Persist.data.screenTime ?? true
    property bool devRecord: false      // LUMEN_DEV: record in a test session, into a throwaway folder
    readonly property bool recording: enabled && (Persist.automates || devRecord)
    readonly property string dir: devRecord ? (Quickshell.env("XDG_RUNTIME_DIR") + "/lumen-dev/screentime")
        : (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/lumen/screentime"

    function dayKey(d) { return Qt.formatDate(d, "yyyy-MM-dd"); }
    property string today: dayKey(new Date())
    property var data: ({ date: today, total: 0, apps: {}, focus: 0, rounds: 0 })
    property bool dirty: false
    property bool loaded: false

    // ── what's happening now ──
    IdleMonitor { id: idle; enabled: root.recording; timeout: 120; respectInhibitors: true }
    readonly property string app: (Hyprland.activeToplevel?.wayland?.appId || Hyprland.activeToplevel?.lastIpcObject?.class || "").toLowerCase()
    readonly property bool counting: recording && loaded && !idle.isIdle && !Lock.locked && !Overview.open

    Timer {
        interval: 5000; repeat: true; running: root.recording
        onTriggered: {
            const k = root.dayKey(new Date());
            if (k !== root.today) { root.save(); root.today = k; root.loaded = false; dayFile.reload(); return; }
            if (!root.counting) return;
            const d = Object.assign({}, root.data, { apps: Object.assign({}, root.data.apps) });
            // Lumen's own windows, portals and dialogs aren't "apps you used"
            if (root.app && !/^(org\.quickshell|org\.freedesktop\.impl\.portal|xdg-desktop-portal|polkit|lumen-)/.test(root.app)) {
                d.apps[root.app] = (d.apps[root.app] ?? 0) + 5;
                d.total += 5;
            }
            if (Focus.mode !== "off") d.focus += 5;
            root.data = d;
            root.dirty = true;
        }
    }
    Timer { interval: 60000; repeat: true; running: root.recording; onTriggered: root.save() }
    Component.onDestruction: save()

    // Pomodoro: a finished focus phase is one round
    property string lastPhase: ""
    Connections {
        target: Countdown
        function onCycleChanged() {
            const ph = Countdown.cycle?.phase ?? "";
            if (root.recording && root.lastPhase === "focus" && ph === "break") {
                root.data = Object.assign({}, root.data, { rounds: root.data.rounds + 1 }); root.dirty = true;
            }
            root.lastPhase = ph;
        }
    }

    FileView {
        id: dayFile
        path: root.dir + "/" + root.today + ".json"
        printErrors: false
        onLoaded: {
            let d = null;
            try { d = JSON.parse(text()); } catch (e) {}
            root.data = Object.assign({ date: root.today, total: 0, apps: {}, focus: 0, rounds: 0 }, d ?? {});
            root.loaded = true;
        }
        onLoadFailed: { root.data = { date: root.today, total: 0, apps: {}, focus: 0, rounds: 0 }; root.loaded = true; }
    }
    function save() {
        if (!recording || !dirty || !loaded) return;
        dirty = false;
        mkdir.running = true;
        dayFile.setText(JSON.stringify(data));
    }
    Process { id: mkdir; command: ["mkdir", "-p", root.dir] }

    // ── the week (for the planner card) ──
    // days: last 7 days oldest first, each { date, total, focus, rounds, apps }
    property var days: []
    readonly property var week: {
        const apps = {};
        let total = 0, focus = 0, rounds = 0;
        for (const d of days) {
            total += d.total; focus += d.focus; rounds += d.rounds;
            for (const a in d.apps) apps[a] = (apps[a] ?? 0) + d.apps[a];
        }
        const top = Object.keys(apps).map(id => ({ id, secs: apps[id] })).sort((a, b) => b.secs - a.secs).slice(0, 5);
        const past = days.slice(0, -1).filter(d => d.total > 0);
        const avg = past.length ? past.reduce((s, d) => s + d.total, 0) / past.length : 0;
        return { total, focus, rounds, top, avg };
    }
    function refreshWeek() {
        save();
        const keys = [];
        for (let i = 6; i >= 0; i--) keys.push(dayKey(new Date(Date.now() - i * 86400000)));
        weekProc.keys = keys;
        weekProc.command = ["sh", "-c", 'cd "$1" 2>/dev/null || exit 0; shift; for k; do cat "$k.json" 2>/dev/null || printf "{}"; echo; done', "sh", dir].concat(keys);
        weekProc.running = true;
    }
    Process {
        id: weekProc
        property var keys: []
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l !== "");
                root.days = weekProc.keys.map((k, i) => {
                    let d = {};
                    try { d = JSON.parse(lines[i] ?? "{}"); } catch (e) {}
                    if (k === root.today) d = root.data;      // live, not the last save
                    return { date: k, total: d.total ?? 0, focus: d.focus ?? 0, rounds: d.rounds ?? 0, apps: d.apps ?? {} };
                });
            }
        }
    }
    // Keep today's bar live while the planner shows it
    Timer { interval: 30000; repeat: true; running: Planner.open; triggeredOnStart: true; onTriggered: root.refreshWeek() }

    // ── names and formatting ──
    function nameOf(id) {
        const e = DesktopEntries.heuristicLookup(id);
        if (e?.name) return e.name;
        return id.replace(/^.*\./, "").replace(/[-_]/g, " ").replace(/^\w/, c => c.toUpperCase());
    }
    function iconOf(id) { const e = DesktopEntries.heuristicLookup(id); return e ? Apps.iconFor(e) : Quickshell.iconPath("application-x-executable"); }
    function fmt(secs) {
        const m = Math.round(secs / 60);
        if (m < 60) return m + "m";
        const h = Math.floor(m / 60), r = m % 60;
        return r ? h + "h " + r + "m" : h + "h";
    }

    // ── housekeeping: older than 60 days → trash; "Clear history" → trash ──
    Timer {
        interval: 30000; running: root.recording
        onTriggered: prune.running = true
    }
    Process {
        id: prune
        command: ["sh", "-c", 'cd "$1" 2>/dev/null || exit 0; find . -maxdepth 1 -name "20??-??-??.json" -mtime +60 -exec gio trash {} + 2>/dev/null; true', "sh", root.dir]
    }
    function clearHistory() {
        dirty = false;
        clearProc.running = true;
    }
    Process {
        id: clearProc
        command: ["sh", "-c", '[ -d "$1" ] && gio trash "$1"; true', "sh", root.dir]
        onExited: { root.data = { date: root.today, total: 0, apps: {}, focus: 0, rounds: 0 }; root.days = []; Island.system("delete", "Screen time cleared", "Moved to the trash"); }
    }

    // ── Monday: last week in one line ──
    Timer {
        interval: 12000; running: root.recording
        onTriggered: if (new Date().getDay() === 1) summaryCheck.running = true
    }
    Process {
        id: summaryCheck
        // Prints last Mon–Sun as JSON lines, unless this Monday's summary was already shown
        command: ["sh", "-c", 'cd "$1" 2>/dev/null || exit 0; mark=.summary-shown; [ "$(cat $mark 2>/dev/null)" = "$2" ] && exit 0; echo "$2" > $mark; shift 2; for k; do cat "$k.json" 2>/dev/null || printf "{}"; echo; done',
                  "sh", root.dir, root.today].concat([7, 6, 5, 4, 3, 2, 1].map(i => root.dayKey(new Date(Date.now() - i * 86400000))))
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l !== "");
                if (lines.length === 0) return;
                let total = 0, focus = 0; const apps = {};
                for (const l of lines) {
                    let d = {}; try { d = JSON.parse(l); } catch (e) {}
                    total += d.total ?? 0; focus += d.focus ?? 0;
                    for (const a in (d.apps ?? {})) apps[a] = (apps[a] ?? 0) + d.apps[a];
                }
                if (total < 600) return;
                const top = Object.keys(apps).sort((a, b) => apps[b] - apps[a])[0];
                Island.push({ kind: "system", key: "screentime:week", priority: Island.priority.system, duration: 6000, queueable: true, force: true,
                              data: { icon: "insights", title: "Last week: " + root.fmt(total) + " on screen",
                                      detail: (focus > 0 ? root.fmt(focus) + " focused · " : "") + "top: " + root.nameOf(top ?? ""), tone: "normal" } });
            }
        }
    }

    // Dev only (LUMEN_DEV): fill a fake week to see the card
    IpcHandler {
        target: "screenTimeTest"
        enabled: Quickshell.env("LUMEN_DEV") === "1"
        function mock(): void {
            const ids = ["code", "brave-origin", "kitty", "org.kde.dolphin", "spotify", "discord"];
            root.days = [6, 5, 4, 3, 2, 1, 0].map(i => {
                const apps = {};
                let total = 0;
                for (const [j, id] of ids.entries()) { const s = Math.round((6 - j) * 1800 * (0.5 + Math.random())); apps[id] = s; total += s; }
                return { date: root.dayKey(new Date(Date.now() - i * 86400000)), total, focus: Math.round(total * 0.3), rounds: 2 + (i % 4), apps };
            });
        }
        function refresh(): void { root.refreshWeek(); }
        function record(): void { root.devRecord = true; root.loaded = false; dayFile.reload(); }
        function state(): string { return JSON.stringify({ app: root.app, counting: root.counting, idle: idle.isIdle, data: root.data }); }
    }
}
