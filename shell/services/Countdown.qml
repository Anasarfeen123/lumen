pragma Singleton
// Timer and stopwatch, shown in the island while running.
//   start: overview search ("timer 5m", "25 min timer", "stopwatch"), IPC
//   island: click pauses / resumes · right-click stops
//   done: chime + "Timer done" (click to dismiss)
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root
    property string mode: ""            // "" | "timer" | "stopwatch"
    property bool paused: false
    property real total: 0              // timer length, ms
    property real acc: 0                // ms accumulated before the current run
    property real runStart: 0
    property string label: ""
    property real now: Date.now()
    readonly property bool active: mode !== ""
    readonly property real elapsed: acc + (paused || !active ? 0 : now - runStart)
    readonly property real remaining: Math.max(0, total - elapsed)
    readonly property real progress: mode === "timer" && total > 0 ? Math.min(1, elapsed / total) : 0
    readonly property string display: fmt(mode === "timer" ? remaining : elapsed)

    function fmt(ms) {
        const s = Math.ceil(ms / 1000), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), ss = s % 60;
        const p = n => String(n).padStart(2, "0");
        return h > 0 ? `${h}:${p(m)}:${p(ss)}` : `${m}:${p(ss)}`;
    }
    function startTimer(ms, name) { mode = "timer"; total = ms; acc = 0; runStart = Date.now(); paused = false; label = name || ""; now = Date.now(); }
    function startStopwatch() { mode = "stopwatch"; total = 0; acc = 0; runStart = Date.now(); paused = false; label = ""; now = Date.now(); }
    function toggle() {
        if (!active) return;
        if (paused) { runStart = Date.now(); paused = false; }
        else { acc += Date.now() - runStart; paused = true; }
    }
    function stop() { mode = ""; paused = false; }

    // "5m", "90s", "1h30m", "25 min", "1:30" (m:ss), plain number = minutes
    function parse(s) {
        s = (s ?? "").trim().toLowerCase();
        let m;
        if ((m = /^(\d+):(\d{2})$/.exec(s))) return ((+m[1]) * 60 + (+m[2])) * 1000;
        if ((m = /^(\d+(?:\.\d+)?)$/.exec(s))) return (+m[1]) * 60000;
        let ms = 0, any = false;
        const re = /(\d+(?:\.\d+)?)\s*(h|hr|hrs|hours?|m|min|mins|minutes?|s|sec|secs|seconds?)\b/g;
        while ((m = re.exec(s))) { any = true; const v = +m[1], u = m[2][0]; ms += v * (u === "h" ? 3600000 : u === "m" ? 60000 : 1000); }
        return any && ms > 0 ? ms : 0;
    }

    Timer {
        interval: 250; repeat: true; running: root.active && !root.paused
        onTriggered: {
            root.now = Date.now();
            if (root.mode === "timer" && root.remaining <= 0) {
                const name = root.label;
                root.stop();
                Sounds.play("alarm", true);
                Island.push({ kind: "system", key: "timerDone", priority: Island.priority.notification, duration: 15000, force: true,
                              data: { icon: "alarm", title: name ? name + " — done" : "Timer done", detail: "Click to dismiss", tone: "normal" } });
            }
        }
    }

    IpcHandler {
        target: "timer"
        function start(spec: string): string { const ms = root.parse(spec); if (!ms) return "couldn't read " + spec; root.startTimer(ms, ""); return "ok"; }
        function stopwatch(): void { root.startStopwatch(); }
        function toggle(): void { root.toggle(); }
        function stop(): void { root.stop(); }
    }
}
