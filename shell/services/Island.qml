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
        const open = pinned || hovered;
        if (kind === "nowPlaying") return open ? "mediaExpanded" : "mediaCompact";
        if (kind === "idle") return open ? (mediaPresent ? "mediaExpanded" : "idlePeek") : "idle";
        return kind;
    }
    readonly property bool expanded: ["mediaExpanded", "notification", "critical", "screenshot"].includes(variant)

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
        if (active) advance();
        else if (kind === "critical") criticalDismissed = true;
        pinned = false;
    }

    function togglePinned() { pinned = !pinned; }
    function unpin() { pinned = false; }

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
    function system(icon, title, detail, tone) {
        push({ kind: "system", key: "system:" + title, priority: priority.system, duration: 2000,
               queueable: true, data: { icon, title, detail: detail ?? "", tone: tone ?? "normal" } });
    }
}
