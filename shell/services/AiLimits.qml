pragma Singleton
// When your coding assistants' limits reset (scripts/ai-limits.py: ccusage for
// Claude Code's 5-hour window, Codex's own logs for its 5-hour and weekly
// limits). A Halo card when one resets — Claude's after a window you used,
// Codex's when you'd used a fair part of it — and a heads-up 10 minutes
// before. "AI limits" in search, or ask Halo "when does claude reset".
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    readonly property bool on: Persist.automates && (Persist.data.aiLimitReminders ?? true)
    property var data: ({})
    // [{ key, name, reset (ms), used (% or -1), what }]
    readonly property var windows: {
        const out = [], c = data.claude, x = data.codex;
        if (c?.active) out.push({ key: "claude:" + c.reset, name: "Claude", reset: c.reset, used: -1, what: "5-hour limit" });
        if (x?.five) out.push({ key: "codex5:" + x.five.reset, name: "Codex", reset: x.five.reset, used: x.five.used, what: "5-hour limit" });
        if (x?.week) out.push({ key: "codexw:" + x.week.reset, name: "Codex", reset: x.week.reset, used: x.week.used, what: "weekly limit" });
        return out;
    }
    // worth a reminder: Claude's block you've been using; Codex at 40 % or more
    function worth(w) { return w.used < 0 || w.used >= 40; }
    function when(ms) {
        const d = new Date(ms), now = new Date();
        const t = Qt.formatTime(d, Theme.clock12h ? "h:mm AP" : "HH:mm");
        return d.toDateString() === now.toDateString() ? t : Qt.formatDate(d, "ddd") + " " + t;
    }
    function left(ms) {
        const m = Math.max(0, Math.round((ms - Date.now()) / 60000));
        return m < 60 ? m + " min" : m < 1440 ? Math.floor(m / 60) + " h " + (m % 60) + " min" : Math.floor(m / 1440) + " d " + Math.floor(m % 1440 / 60) + " h";
    }

    function refresh() { if (!proc.running) proc.running = true; }
    Process {
        id: proc
        command: [Theme.lumenRoot + "/scripts/ai-limits.py"]
        stdout: StdioCollector { onStreamFinished: { try { root.data = JSON.parse(text); } catch (e) {} if (root.showing) { root.showing = false; root.card(); } } }
    }
    Timer { interval: LowPower.defer ? 20 * 60000 : 5 * 60000; repeat: true; triggeredOnStart: true; running: root.on; onTriggered: root.refresh() }

    // once a reminder has been said, never again (kept across reloads)
    function said(key) {
        const s = Persist.data.aiLimitsSaid ?? [];
        if (s.includes(key)) return true;
        Persist.data.aiLimitsSaid = s.concat([key]).slice(-40);
        return false;
    }
    Timer {
        interval: 30000; repeat: true; running: root.on
        onTriggered: {
            const now = Date.now();
            for (const w of root.windows) {
                if (!root.worth(w)) continue;
                const until = w.reset - now;
                if (until > 0 && until <= 10 * 60000 && !root.said("soon:" + w.key))
                    Halo.say({ key: "ailimit-soon", icon: "hourglass_bottom", title: w.name + " resets in " + root.left(w.reset),
                               text: "Your " + w.name + " " + w.what + " starts over at " + root.when(w.reset) + ".", level: "asked", duration: 10000, speak: false });
                // reset — said only if it just happened (not for an old one found at startup)
                if (until <= 0 && until > -15 * 60000 && !root.said("reset:" + w.key))
                    Halo.say({ key: "ailimit-reset", icon: "restart_alt", title: w.name + " has reset",
                               text: "Your " + w.what + " is fresh again" + (w.used >= 0 ? " (you'd used " + Math.round(w.used) + "%)." : "."),
                               level: "important", tone: "happy", duration: 15000, speak: false });
            }
        }
    }

    // all of them, on demand (with fresh numbers: the card waits for them)
    property bool showing: false
    function show() { showing = true; refresh(); }
    function card() {
        const now = Date.now();
        const lines = windows.map(w => w.name + " " + w.what + ": " + (w.reset > now ? "resets " + when(w.reset) + " (in " + left(w.reset) + ")" : "fresh")
                                       + (w.used >= 0 && w.reset > now ? " · " + Math.round(w.used) + "% used" : ""));
        if (data.claude && !data.claude.active) lines.unshift("Claude: no 5-hour window running — it starts when you next use it");
        Halo.say({ key: "ailimits", icon: "hourglass_top", title: "AI limits", level: "asked", duration: 15000, speak: false,
                   text: lines.length ? lines.join("\n") : "No Claude Code or Codex usage found on this computer." });
    }
    IpcHandler { target: "ailimits"; function open(): void { root.show(); }   // (not "show": qs ipc call reserves it)
                function state(): string { return JSON.stringify(root.windows); } }
}
