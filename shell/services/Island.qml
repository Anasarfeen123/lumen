pragma Singleton

// Island controller — decides WHAT the island shows. Views only render it.
//
// Two kinds of content (DESIGN.md §8.2):
//   persistent  derived from system state, shown while true
//               critical battery > recording
//               (music is NOT persistent: it announces itself briefly, then the
//               clock returns with an equalizer — see content/Idle.qml)
//   transient events with a lifetime (OSD, notification, system, …)
//
// Transient rules
//   • lower `priority` number wins; a higher-priority event replaces the
//     current one, which is re-queued if it is `queueable`
//   • an event with the same `key` as the current one updates it in place
//     (volume key bursts don't re-animate)
//   • hovering or pinning pauses the dismiss timer
//   • queued events go stale: anything older than its duration + 4 s is
//     dropped instead of replayed (notifications live on in history)
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Priorities (lower = more important). User feedback beats ambient info.
    readonly property QtObject priority: QtObject {
        readonly property int osd: 1          // volume / brightness / mic — direct response to input
        readonly property int notification: 2
        readonly property int system: 3
        readonly property int screenshot: 4
        readonly property int nowPlaying: 5
        readonly property int workspace: 6
    }

    property var active: null
    property var queue: []
    property bool hovered: false        // hover *intent* (delayed) — drives expansion
    property bool pointerInside: false  // raw — pauses the dismiss timer immediately
    property bool pinned: false
    property bool ready: false

    // Where the focused island currently is — the overview's search field
    // starts from exactly this shape so the island appears to become it.
    property real shapeWidth: 120
    property real shapeY: 8

    // ── persistent sources (fed by IslandSources) ──
    property bool recording: false
    property date recordingSince: new Date()
    property bool criticalBattery: false
    property bool criticalDismissed: false
    property bool mediaPlaying: false
    property bool mediaPresent: false

    readonly property string persistentKind:
        (criticalBattery && !criticalDismissed) ? "critical"
        : recording ? "recording"
        : Countdown.active ? "timer"
        : "idle"

    readonly property string kind: active?.kind ?? persistentKind
    readonly property var info: active?.data ?? ({})

    // The exact view to render
    readonly property string variant: {
        if (timelineOpen) return "timeline";
        const open = pinned || hovered;
        if (kind === "nowPlaying") return open ? "mediaExpanded" : "mediaCompact";
        // Hovering the resting island: music you're playing, else what you're
        // working on (Context), else a paused player, else date and time
        if (kind === "idle") return !open ? "idle"
            : mediaPlaying ? "mediaExpanded"
            : (Context.kind === "dev" || Context.kind === "game") ? "context"
            : mediaPresent ? "mediaExpanded" : "idlePeek";
        return kind;
    }
    readonly property bool expanded: ["mediaExpanded", "notification", "critical", "screenshot", "context", "device", "timeline", "message"].includes(variant)

    Timer {
        interval: 2000
        running: true
        onTriggered: root.ready = true
    }

    Timer {
        id: dismissTimer
        interval: root.active?.duration ?? 2000
        running: root.active !== null && !root.pointerInside && !root.pinned
        onTriggered: root.advance()
    }

    // ev: { kind, priority, duration, key?, queueable?, data, force? }
    function push(ev) {
        if (!ready && !ev.force) return;
        ev.key = ev.key ?? ev.kind;
        ev.createdAt = ev.createdAt ?? Date.now();
        remember(ev);
        if (active && active.key === ev.key) {
            active = ev;
            dismissTimer.restart();
            return;
        }
        if (!active || ev.priority <= active.priority) {
            if (active && active.queueable) enqueue(active);
            active = ev;
            dismissTimer.restart();
        } else if (ev.queueable) {
            enqueue(ev);
        }
    }

    function enqueue(ev) {
        const q = queue.filter(e => e.key !== ev.key);
        q.push(ev);
        q.sort((a, b) => a.priority - b.priority);
        queue = q;
    }

    function advance() {
        const now = Date.now();
        const q = queue.filter(e => now - e.createdAt < e.duration + 4000);
        active = q.shift() ?? null;
        queue = q;
        if (active) dismissTimer.restart();
    }

    function dismiss() {
        if (timelineOpen) { closeTimeline(); return; }
        if (active) advance();
        else if (kind === "critical") criticalDismissed = true;
        pinned = false;
    }

    function togglePinned() { pinned = !pinned; }
    function unpin() { pinned = false; timelineOpen = false; }

    // ── "Now" timeline ─────────────────────────────────────────────────────
    // Scrub the last hour like a film strip (Shift+scroll or sideways scroll on
    // the island): notifications, what the island announced, and what's
    // coming up in the next hour. Kept in memory only.
    property var recent: []             // [{ time, key, kind, icon, title, detail, path? }]
    function remember(ev) {
        if (!["system", "device", "screenshot"].includes(ev.kind)) return;   // notifications come from their history
        const d = ev.data ?? {};
        const item = ev.kind === "screenshot"
            ? { icon: "screenshot_monitor", title: "Screenshot", detail: (d.path ?? "").replace(/^.*\//, ""), path: d.path ?? "" }
            : { icon: d.icon ?? "info", title: d.title ?? "", detail: d.detail ?? "" };
        if (!item.title) return;
        const now = Date.now();
        let r = recent.filter(e => now - e.time < 3600000);
        // A burst of the same thing (volume, progress updates) is one moment
        if (r.length && r[r.length - 1].key === ev.key && now - r[r.length - 1].time < 10000) r.pop();
        r.push(Object.assign({ time: now, key: ev.key, kind: ev.kind }, item));
        recent = r.slice(-50);
    }
    function timelineEntries() {
        const now = Date.now(), hour = 3600000, out = [];
        for (const e of recent) if (now - e.time < hour) out.push(Object.assign({}, e));
        const h = Notifications.model;
        for (let i = 0; i < h.count; i++) {
            const e = h.get(i);
            if (now - e.time >= hour) continue;
            out.push({ time: e.time, kind: "notification", icon: "notifications", image: e.icon, nid: e.nid,
                       title: e.summary || e.appName, detail: [e.appName, Notifications.plain(e.body)].filter(x => x).join(" · ") });
        }
        for (const e of (Planner.upcoming ?? []))
            if (!e.allDay && e.when > now && e.when - now <= hour)
                out.push({ time: e.when, kind: "event", icon: "event", title: e.title, detail: "Coming up", future: true });
        return out.sort((a, b) => a.time - b.time);
    }
    property bool timelineOpen: false
    property var timeline: []
    property int timelineIndex: 0
    readonly property var timelineItem: timeline[timelineIndex] ?? null
    function openTimeline() {
        timeline = timelineEntries();
        const now = Date.now();
        let i = timeline.length - 1;
        while (i > 0 && timeline[i].future && timeline[i].time > now) i--;       // start at "just now", not the future
        timelineIndex = Math.max(0, i);
        timelineOpen = true;
        pinned = true;                  // keyboard: ←/→ scrub, Esc closes
    }
    // Dev only (LUMEN_DEV): an hour of sample moments
    IpcHandler {
        target: "timelineTest"
        enabled: Quickshell.env("LUMEN_DEV") === "1"
        function scrub(steps: int): void { root.scrub(steps); }
        function fill(): void {
            const now = Date.now(), m = 60000;
            root.recent = [
                { time: now - 52 * m, key: "a", kind: "device", icon: "keyboard", title: "Keychron K2", detail: "Keyboard · connected by USB" },
                { time: now - 41 * m, key: "b", kind: "system", icon: "bluetooth_connected", title: "WH-CH520", detail: "82% battery" },
                { time: now - 33 * m, key: "c", kind: "screenshot", icon: "screenshot_monitor", title: "Screenshot", detail: "Screenshot_2026-09-26_19-02.png" },
                { time: now - 21 * m, key: "d", kind: "system", icon: "task_alt", title: "Build finished", detail: "2m 14s" },
                { time: now - 9 * m, key: "e", kind: "system", icon: "wifi", title: "VITC-HOS2-4", detail: "Connected" },
                { time: now - 2 * m, key: "f", kind: "device", icon: "hard_drive", title: "BACKUP", detail: "USB drive · 63.9 GB · EXFAT" },
            ];
        }
    }
    function closeTimeline() { timelineOpen = false; pinned = false; }
    function toggleTimeline() { if (timelineOpen) closeTimeline(); else openTimeline(); }
    // steps < 0: back in time
    function scrub(steps) {
        if (!timelineOpen) { openTimeline(); return; }
        timelineIndex = Math.max(0, Math.min(timeline.length - 1, timelineIndex + steps));
    }

    // Convenience emitters
    function osd(channel, icon, value, label) {
        push({ kind: "osd", key: "osd", priority: priority.osd, duration: 1200,
               data: { channel, icon, value, label: label ?? "" } });
    }
    // Long-running work: value 0–100, or -1 when there's no estimate.
    // Updates in place (same id); it lingers 6 s after the last update.
    function progress(id, icon, title, value, detail) {
        push({ kind: "progress", key: "progress:" + id, priority: priority.system, duration: 6000, queueable: true, force: true,
               data: { icon, title, value, detail: detail ?? "" } });
    }
    // A plugged-in device worth a card (new, or something you can act on)
    function device(id, data) {
        push({ kind: "device", key: "device:" + id, priority: priority.system, duration: 6000,
               queueable: true, data });
    }
    function system(icon, title, detail, tone) {
        push({ kind: "system", key: "system:" + title, priority: priority.system, duration: 2000,
               queueable: true, data: { icon, title, detail: detail ?? "", tone: tone ?? "normal" } });
    }
}
