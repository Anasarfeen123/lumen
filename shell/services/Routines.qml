pragma Singleton
// Halo's routines and watches — "when X, do Y", set up in plain words:
//   routines (keep going)   "every weekday at 8:30, brief me"
//                           "whenever I plug in the charger, battery saver off"
//                           "when I connect a monitor, focus work"
//                           "when I open spotify, do not disturb on"
//                           "when I join VIT-WiFi, mute"
//                           "when the battery drops to 20%, dim the screen"
//                           "when I unlock, what did I miss"
//   watches (once)          "tell me when the download finishes"
//                           "tell me when Arya replies"
//                           "tell me when ffmpeg finishes"
// The action is anything Halo does directly (Halo.intent: settings, timers,
// focus modes, briefs, music…); otherwise it's said as a reminder. Routines
// never start open-ended jobs on their own. Kept in shell.json; Settings →
// Halo → Routines lists them; "what are my routines" too.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root
    readonly property var list: Persist.data.haloRoutines ?? []
    readonly property bool active: Persist.automates || dev
    property bool dev: false

    function add(r) {
        r.id = "r" + Date.now() + Math.floor(Math.random() * 1000);
        r.made = Date.now();
        Persist.data.haloRoutines = list.concat([r]);
        return r;
    }
    function remove(id) { Persist.data.haloRoutines = list.filter(r => r.id !== id); }
    function describe(r) {
        const t = r.trigger;
        const days = d => d === "daily" ? "every day" : d === "weekdays" ? "every weekday" : d === "weekend" ? "at weekends" : "every " + d;
        let when = t.type;
        switch (t.type) {
        case "time": when = days(t.days) + " at " + t.at; break;
        case "power": when = "when the charger is " + (t.on ? "plugged in" : "unplugged"); break;
        case "display": when = "when a monitor is connected"; break;
        case "app": when = "when " + t.name + " opens"; break;
        case "wifi": when = "when you join " + t.ssid; break;
        case "unlock": when = "when you unlock"; break;
        case "battery": when = "when the battery drops to " + t.below + "%"; break;
        case "download": when = "when the download finishes"; break;
        case "chat": when = "when " + t.name + " messages you"; break;
        case "process": when = "when " + t.name + " finishes"; break;
        }
        return (r.once ? "Once, " : "") + when + (r.action ? " → " + r.action : " → tell you");
    }

    // ── understanding "when … , …" ──
    function parseTime(s) {
        const m = /^(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$/.exec(s.trim());
        if (!m) return "";
        let h = +m[1]; const min = +(m[2] ?? 0);
        if (m[3] === "pm" && h < 12) h += 12;
        if (m[3] === "am" && h === 12) h = 0;
        if (h > 23 || min > 59) return "";
        return (h < 10 ? "0" : "") + h + ":" + (min < 10 ? "0" : "") + min;
    }
    // Returns an intent (for Halo.handle) or null
    function intent(q) {
        const l = q.trim().replace(/[.!]+$/, "");
        let m;
        const done = (r, text) => ({ glyph: "schedule", title: text, plain: true, run: () => root.add(r) });
        // every <day> at <time>, <action>
        if ((m = /^(?:every|each)\s+(day|weekday|weekdays|weekend|weekends|morning|evening|night|monday|tuesday|wednesday|thursday|friday|saturday|sunday)s?\s+at\s+([\d:]+\s*(?:am|pm)?)\s*[,:-]?\s*(?:then\s+)?(.+)$/i.exec(l))) {
            const at = parseTime(m[2]);
            if (!at) return null;
            const d = m[1].toLowerCase();
            const days = /^(day|morning|evening|night)$/.test(d) ? "daily" : /^weekdays?$/.test(d) ? "weekdays" : /^weekends?$/.test(d) ? "weekend" : d;
            const r = { trigger: { type: "time", at, days }, action: m[3].trim() };
            return done(r, "Routine set: " + describe(r));
        }
        // tell me when … (once)
        if ((m = /^(?:tell|let|ping|notify) me (?:know )?when (?:the |my )?downloads? (?:finish(?:es)?|is done|completes?|are done)$/i.exec(l)))
            return done({ trigger: { type: "download" }, action: "", once: true }, "I'll tell you when the download finishes");
        if ((m = /^(?:tell|let|ping|notify) me (?:know )?when ([\w .'-]{2,40}?) (?:replies|messages(?: me)?|texts(?: me)?|answers|writes(?: back)?)$/i.exec(l)))
            return done({ trigger: { type: "chat", name: m[1].trim() }, action: "", once: true }, "I'll tell you when " + m[1].trim() + " messages you");
        if ((m = /^(?:tell|let|ping|notify) me (?:know )?when (?:the )?([\w.+-]{2,40}) (?:finishes|is done|exits|ends|stops|completes)$/i.exec(l)) && !/download|battery|build$/i.test(m[1]))
            return done({ trigger: { type: "process", name: m[1].trim() }, action: "", once: true }, "I'll tell you when " + m[1].trim() + " finishes");
        if ((m = /^(?:tell|let|ping|notify) me (?:know )?when (?:the |my )?battery (?:hits|reaches|is at|drops to|falls to|gets to|is below|goes below) (\d{1,2})\s*%?$/i.exec(l)))
            return done({ trigger: { type: "battery", below: +m[1] }, action: "", once: true }, "I'll tell you at " + m[1] + "% battery");
        // when(ever) … , action (keep going)
        if ((m = /^when(?:ever)?\s+(.+?)\s*[,:-]\s*(?:then\s+)?(.+)$/i.exec(l)) || (m = /^when(?:ever)?\s+(.+?)\s+then\s+(.+)$/i.exec(l))) {
            const cond = m[1].toLowerCase(), action = m[2].trim();
            let t = null, x;
            if (/\b(plug(?:ged)? in|connect)\b.*\bcharger\b|\bcharging\b|\bplugged in\b/.test(cond)) t = { type: "power", on: true };
            else if (/\bunplug|on battery\b/.test(cond)) t = { type: "power", on: false };
            else if (/\b(monitor|display|hdmi|screen|projector)\b/.test(cond)) t = { type: "display" };
            else if (/\bunlock|log ?in|come back\b/.test(cond)) t = { type: "unlock" };
            else if ((x = /battery (?:hits|reaches|is at|drops to|falls to|gets to|is below|goes below) (\d{1,2})/.exec(cond))) t = { type: "battery", below: +x[1] };
            else if ((x = /(?:join|connect to|am on|i'?m on)\s+(?:the\s+)?(?:wi-?fi\s+)?(.+?)(?:\s+wi-?fi)?$/.exec(cond))) t = { type: "wifi", ssid: x[1] };
            else if ((x = /(?:open|start|launch)\s+(?:the\s+)?(.+)$/.exec(cond))) t = { type: "app", name: x[1] };
            if (!t) return null;
            const r = { trigger: t, action };
            return done(r, "Routine set: " + describe(r));
        }
        if (/^(what are|show|list) (my )?(routines|watches|automations)$|^my (routines|automations)$/i.test(l))
            return { glyph: "schedule", title: "Your routines", own: () => Halo.say({ key: "routines", icon: "schedule", title: list.length ? list.length + (list.length === 1 ? " routine" : " routines") : "No routines yet",
                    text: list.length ? list.map(r => "• " + describe(r)).join("\n") : "Try: “every weekday at 8:30, brief me” or “tell me when the download finishes”.", level: "asked", duration: 15000,
                    actions: list.length ? [{ label: "Manage", icon: "settings", run: () => SettingsState.launch("ai") }] : [] }) };
        return null;
    }

    // ── firing ──
    function fire(r, why) {
        if (r.once) remove(r.id);
        if (!r.action) {
            Sounds.play("done");
            Halo.say({ key: "watch:" + r.id, icon: "notifications_active", title: why, text: "", level: "urgent", tone: "happy", duration: 10000 });
            return;
        }
        // Lumen's own actions, never an open-ended job
        const it = Halo.intent(r.action);
        if (it && !it.ask) {
            Halo.handle(r.action, "island");
            return;
        }
        Halo.say({ key: "routine:" + r.id, icon: "schedule", title: r.action, text: "Your routine (" + describe(r).replace(/ → .*$/, "") + ")", level: "important", duration: 12000,
                   actions: Ai.configured ? [{ label: "Ask " + Halo.name, icon: "auto_awesome", run: () => { Ai.show(); Ai.send(r.action); } }] : [] });
    }
    function each(type, test, why) {
        if (!active) return;
        for (const r of list.slice()) if (r.trigger.type === type && test(r.trigger)) fire(r, why(r.trigger));
    }

    // time: once a minute
    property string lastMinute: ""
    Timer {
        interval: 15000; repeat: true; running: root.active && root.list.some(r => r.trigger.type === "time")
        onTriggered: {
            const now = new Date(), key = Qt.formatTime(now, "HH:mm");
            if (key === root.lastMinute) return;
            root.lastMinute = key;
            const dow = now.getDay(), name = ["sunday", "monday", "tuesday", "wednesday", "thursday", "friday", "saturday"][dow];
            root.each("time", t => t.at === key && (t.days === "daily" || (t.days === "weekdays" && dow >= 1 && dow <= 5) || (t.days === "weekend" && (dow === 0 || dow === 6)) || t.days === name), t => "It's " + t.at);
        }
    }
    Connections { target: Battery; function onPluggedInChanged() { if (Island.ready) root.each("power", t => t.on === Battery.pluggedIn, t => t.on ? "Charger connected" : "On battery"); } }
    property var batteryFired: ({})
    Connections {
        target: Battery
        function onPercentageChanged() {
            if (Battery.pluggedIn) { root.batteryFired = ({}); return; }
            if (!root.active) return;
            const p = Math.round(Battery.percentage * 100);
            const hit = root.list.filter(r => r.trigger.type === "battery" && p <= r.trigger.below && !root.batteryFired[r.id]).map(r => r.id);
            if (!hit.length) return;
            const f = Object.assign({}, root.batteryFired); for (const id of hit) f[id] = true; root.batteryFired = f;
            for (const r of root.list.filter(x => hit.includes(x.id))) root.fire(r, "Battery at " + p + "%");
        }
    }
    Connections { target: Hyprland; function onRawEvent(ev) { if (ev.name === "monitoraddedv2") root.each("display", t => true, t => "Monitor connected"); } }
    Connections { target: Lock; function onLockedChanged() { if (!Lock.locked) unlockTimer.restart(); } }
    Timer { id: unlockTimer; interval: 2500; onTriggered: root.each("unlock", t => true, t => "Welcome back") }
    Connections { target: Network; function onSsidChanged() { const s = (Network.ssid ?? "").toLowerCase(); if (s) root.each("wifi", t => s === t.ssid.toLowerCase() || s.includes(t.ssid.toLowerCase()), t => "On " + Network.ssid); } }
    Connections { target: Downloads; function onDone(name) { root.each("download", t => true, t => "Downloaded " + name); } }
    // a window of that app appears
    property var seenWindows: ({})
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name !== "openwindow") return;
            const parts = ev.data.split(",");          // address,workspace,class,title
            const cls = (parts[2] ?? "").toLowerCase(), title = (parts.slice(3).join(",") ?? "").toLowerCase();
            const name = (Apps.entryFor(parts[2] ?? "")?.name ?? "").toLowerCase();
            root.each("app", t => { const n = t.name.toLowerCase(); return cls.includes(n) || name.includes(n) || title.includes(n); }, t => t.name + " opened");
        }
    }
    // a chat message from someone
    Connections {
        target: Inbox
        function onConversationsChanged() {
            for (const c of Inbox.unreadConversations) root.each("chat", t => c.title.toLowerCase().includes(t.name.toLowerCase()), t => c.title + " messaged you");
        }
    }
    // a program finishing: look every few seconds while one is watched
    Timer {
        interval: 4000; repeat: true; running: root.active && root.list.some(r => r.trigger.type === "process")
        onTriggered: if (!procCheck.running) procCheck.running = true
    }
    Process {
        id: procCheck
        command: ["sh", "-c", "ps -u \"$(id -u)\" -o comm= | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: {
                const running = text.split("\n").map(x => x.trim().toLowerCase());
                root.each("process", t => {
                    const n = t.name.toLowerCase();
                    const alive = running.some(p => p === n || p.startsWith(n));
                    if (alive) { t.seen = true; return false; }
                    return t.seen === true;
                }, t => t.name + " finished");
                // remember "seen" (it has to be running first)
                Persist.data.haloRoutines = root.list.map(r => r.trigger.type === "process" && running.some(p => p.startsWith(r.trigger.name.toLowerCase())) ? Object.assign({}, r, { trigger: Object.assign({}, r.trigger, { seen: true }) }) : r);
            }
        }
    }

    IpcHandler {
        target: "routines"
        function list(): string { return JSON.stringify(root.list.map(r => root.describe(r))); }
        function add(text: string): bool { const it = root.intent(text); if (!it) return false; it.run ? it.run() : it.own(); return true; }
        function clear(): void { Persist.data.haloRoutines = []; }
        // Dev only (LUMEN_DEV): fire every routine of a kind
        function fire(type: string): void { if (Quickshell.env("LUMEN_DEV") === "1") { root.dev = true; root.each(type, t => true, t => "Test: " + type); } }
    }
}
