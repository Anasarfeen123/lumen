pragma Singleton
// Halo's wrap-ups — what Lumen already knows, said in one card:
//   morning   the first unlock of the day: greeting, weather, today's classes
//             and events, an exam coming up, anything that came in overnight
//   away      back after 10+ minutes locked: notifications by app, WhatsApp
//             chats, finished downloads, what Halo held, what's next
//   evening   at the time you chose (Settings → Halo, default 21:30): your
//             screen time and focus, what's left unread, tomorrow's first
//             class, exams and events — and "Sleep mode" one tap away
// Ask any time: "what did I miss", "brief me", "wrap up my day".
// Built locally from data already on this computer; "Summarise" hands the
// notifications to Halo's model only when you press it.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root
    readonly property bool active: Persist.automates || dev

    property bool dev: false
    property real awayFrom: 0
    property var downloads: []          // [{ name, at }] this session
    Connections { target: Downloads; function onDone(name, at) { root.downloads = root.downloads.concat([{ name, at }]).slice(-20); } }

    function dayKey(d) { return Qt.formatDate(d ?? new Date(), "yyyy-MM-dd"); }
    function plural(n, one, many) { return n + " " + (n === 1 ? one : (many ?? one + "s")); }
    function list(a) { return a.length <= 1 ? (a[0] ?? "") : a.slice(0, -1).join(", ") + " and " + a[a.length - 1]; }
    function clock(ms) { return Qt.formatTime(new Date(ms), Theme.timeFormatFull); }

    // ── coming back ──
    Connections {
        target: Lock
        function onLockedChanged() {
            if (Lock.locked) { root.awayFrom = Date.now(); return; }
            if (!root.active) return;
            backTimer.restart();
        }
    }
    Timer {
        id: backTimer
        interval: 1600                  // after the unlock animation
        onTriggered: {
            if (Persist.data.haloMorning !== false && root.morningDue()) root.morning(false);
            else if (Persist.data.haloAway !== false && root.awayFrom > 0 && Date.now() - root.awayFrom >= 10 * 60000) root.away(false);
        }
    }
    // Not locked at the first look of the day (the shell started this morning)
    Timer {
        interval: 20000; running: root.active; repeat: true; triggeredOnStart: false
        onTriggered: {
            if (!Lock.locked && Persist.data.haloMorning !== false && root.morningDue() && root.idleOk()) root.morning(false);
            const w = Persist.data.haloWrapUp ?? "";
            const m = /^(\d{1,2}):(\d{2})$/.exec(w);
            if (!m) return;
            const now = new Date(), at = new Date(now.getFullYear(), now.getMonth(), now.getDate(), +m[1], +m[2]);
            if (now >= at && now - at < 3 * 3600000 && Persist.data.haloLastWrap !== root.dayKey(now)) root.evening(false);
        }
    }
    function idleOk() { return !Overview.open; }
    function morningDue() {
        const h = new Date().getHours();
        return h >= 5 && h < 12 && Persist.data.haloLastMorning !== dayKey();
    }

    // ── what came in since a moment ──
    function since(t) {
        const by = {}, texts = [];
        const h = Notifications.model;
        let n = 0;
        for (let i = 0; i < h.count; i++) {
            const e = h.get(i);
            if (e.time <= t) continue;
            if (/whatsapp|whatsie|zapzap|karere/i.test(e.appName ?? "")) continue;      // chats are counted below
            n++;
            by[e.appName || "Other"] = (by[e.appName || "Other"] ?? 0) + 1;
            texts.push("- " + (e.appName || "") + ": " + (e.summary || "") + (e.body ? " — " + Notifications.plain(e.body).slice(0, 160) : ""));
        }
        const apps = Object.keys(by).sort((a, b) => by[b] - by[a]);
        const chats = Inbox.unreadConversations.filter(c => (c.lastTime ?? 0) > t);
        const dls = downloads.filter(d => d.at > t);
        return { n, apps, by, texts, chats, dls };
    }
    function sinceLine(s) {
        const parts = [];
        if (s.n) parts.push(plural(s.n, "notification") + " — " + s.apps.slice(0, 3).map(a => a + (s.by[a] > 1 ? " " + s.by[a] : "")).join(", ") + (s.apps.length > 3 ? "…" : ""));
        if (s.chats.length) parts.push("WhatsApp: " + s.chats.slice(0, 3).map(c => c.title + (c.unread > 1 ? " (" + c.unread + ")" : "")).join(", ") + (s.chats.length > 3 ? " +" + (s.chats.length - 3) : ""));
        if (s.dls.length) parts.push((s.dls.length === 1 ? "Downloaded " + s.dls[0].name : plural(s.dls.length, "download") + " finished"));
        return parts;
    }
    function nextUp() {
        const now = Date.now();
        const ev = (Planner.upcoming ?? []).find(e => !e.allDay && e.when > now && e.when - now < 3 * 3600000);
        const cls = Amazecc.cfg?.enabled && Amazecc.ready ? Amazecc.next : null;
        const clsAt = cls ? new Date().setHours(Math.floor(cls.start / 60), cls.start % 60, 0, 0) : 0;
        if (cls && (!ev || clsAt < ev.when)) return "Next: " + cls.title + " at " + Amazecc.clockLabel(cls.start) + (cls.venue ? ", " + cls.venue : "");
        if (ev) return "Next: " + ev.title + " at " + clock(ev.when);
        return "";
    }
    function catchUpActions(s) {
        return [s.n ? { label: "Show", icon: "notifications", run: () => Sidebar.show("notifications") } : null,
                s.chats.length ? { label: "Reply", icon: "reply", run: () => Inbox.showPanel(s.chats.length === 1 ? s.chats[0].key : "") } : null,
                s.n >= 3 && Ai.configured ? { label: "Summarise", icon: "auto_awesome", run: () => root.summarise(s) } : null].filter(a => a);
    }
    function summarise(s) {
        Ai.show();
        Ai.send("Summarise these notifications for me in a few bullets: what needs a reply or action first, then the rest in one line.\n\n" + s.texts.slice(-40).join("\n"));
    }

    function away(asked) {
        const t = awayFrom > 0 && (asked ? true : Date.now() - awayFrom >= 10 * 60000) ? awayFrom : Date.now() - 3600000;
        const s = since(t);
        const held = Halo.held;
        Halo.held = [];
        const parts = sinceLine(s);
        if (held.length) parts.push(held.map(c => c.title).join(" · "));
        const next = nextUp();
        if (next) parts.push(next);
        const mins = Math.round((Date.now() - t) / 60000);
        if (!s.n && !s.chats.length && !s.dls.length && !held.length) {
            if (!asked && Halo.chattiness !== "companion") return;
            Halo.say({ key: "away", icon: "done_all", title: asked ? "Nothing new" : "Welcome back", text: (asked ? "Nothing came in" : "Nothing new") + (mins >= 60 ? " in the last " + Math.round(mins / 60) + " h" : "") + "." + (next ? " " + next + "." : ""),
                       level: asked ? "asked" : "chatter", tone: "happy" });
            return;
        }
        Halo.say({ key: "away", icon: "inbox", title: asked ? "Here's what you missed" : "While you were away" + (mins >= 60 ? " (" + Math.round(mins / 60) + " h)" : ""),
                   text: parts.join(" · "), level: asked ? "asked" : "important", duration: 14000,
                   speak: "Welcome back" + (Halo.you ? ", " + Halo.you : "") + ". " + [s.n ? plural(s.n, "notification") : "", s.chats.length ? plural(s.chats.length, "WhatsApp chat") : ""].filter(x => x).join(" and ") + ".",
                   actions: catchUpActions(s).concat(held.length ? [{ label: "What Halo held", icon: "auto_awesome", run: () => Ai.show() }] : []) });
        Halo.log = Halo.log.concat(held).slice(-20);
    }

    function morning(asked) {
        if (!asked) Persist.data.haloLastMorning = dayKey();
        const parts = [];
        if (Weather.ready) parts.push(Math.round(Weather.now.temp) + "° and " + Weather.describe(Weather.now.code).toLowerCase() + (Weather.days?.[0] ? " (high " + Math.round(Weather.days[0].max) + "°)" : ""));
        if (Amazecc.cfg?.enabled && Amazecc.ready) {
            const today = Amazecc.today;
            if (today.length) parts.push(plural(today.length, "class", "classes") + " — first " + today[0].title + " at " + Amazecc.clockLabel(today[0].start) + (today[0].venue ? ", " + today[0].venue : ""));
            else if (Amazecc.todayInfo?.kind === "holiday") parts.push("No classes today" + (Amazecc.todayInfo.text ? " (" + Amazecc.todayInfo.text.toLowerCase() + ")" : ""));
            const ex = Amazecc.nextExam;
            if (ex && ex.when - Date.now() < 4 * 86400000 && Amazecc.examCountdown) parts.push(Amazecc.examCountdown);
        }
        const end = new Date(); end.setHours(23, 59, 59, 999);
        const ev = (Planner.upcoming ?? []).filter(e => !e.external && e.when <= end.getTime() && e.when >= Date.now() - 3600000);
        if (ev.length) parts.push(ev.slice(0, 2).map(e => e.title + (e.allDay ? "" : " at " + clock(e.when))).join(", ") + (ev.length > 2 ? " +" + (ev.length - 2) : ""));
        const rem = Halo.reminders.filter(r => r.at <= end.getTime());
        if (rem.length) parts.push(plural(rem.length, "reminder") + " today");
        const s = since(awayFrom > 0 ? awayFrom : Date.now() - 8 * 3600000);
        parts.push(...sinceLine(s));
        if (Battery.available && !Battery.pluggedIn && Battery.percentage < 0.3) parts.push("battery at " + Math.round(Battery.percentage * 100) + "% — plug in before you head out");
        // an exam within two days: Halo is a little anxious for you
        const examSoon = HaloCollege.on && Amazecc.nextExam && Amazecc.nextExam.when - Date.now() < 2 * 86400000;
        Halo.say({ key: "morning", icon: "wb_sunny", title: Halo.greeting(), text: parts.join(" · ") || "Nothing on the calendar. A clear day.",
                   level: asked ? "asked" : "important", tone: examSoon ? "concerned" : "happy", duration: 15000,
                   speak: Halo.greeting() + " " + parts.slice(0, 3).join(". ") + ".",
                   actions: [{ label: "Today's plan", icon: "event_note", run: () => { Planner.open = true; } }].concat(catchUpActions(s)) });
    }

    function evening(asked) {
        if (!asked) Persist.data.haloLastWrap = dayKey();
        const parts = [];
        const st = ScreenTime.data ?? {};
        if (st.total > 300) {
            const top = Object.keys(st.apps ?? {}).sort((a, b) => st.apps[b] - st.apps[a]).slice(0, 2).map(id => ScreenTime.nameOf(id));
            parts.push(ScreenTime.fmt(st.total) + " on screen" + (top.length ? ", mostly " + list(top) : ""));
        }
        if ((st.rounds ?? 0) > 0) parts.push(plural(st.rounds, "focus round") + " done");
        const midnight = new Date(); midnight.setHours(0, 0, 0, 0);
        const s = since(midnight.getTime());
        if (s.chats.length || Inbox.unreadTotal) parts.push(plural(Inbox.unreadConversations.length, "chat") + " still unread");
        const tomorrow = new Date(midnight.getTime() + 86400000);
        if (Amazecc.cfg?.enabled && Amazecc.ready) {
            const c = Amazecc.classesOn(tomorrow);
            parts.push(c.length ? "Tomorrow: " + plural(c.length, "class", "classes") + ", first at " + Amazecc.clockLabel(c[0].start) + " (" + c[0].title + ")" : "No classes tomorrow");
            const ex = Amazecc.nextExam;
            if (ex && ex.when - Date.now() < 4 * 86400000 && Amazecc.examCountdown) parts.push(Amazecc.examCountdown);
        }
        const ev = (Planner.upcoming ?? []).filter(e => !e.external && e.when >= tomorrow.getTime() && e.when < tomorrow.getTime() + 86400000);
        if (ev.length) parts.push(ev.slice(0, 2).map(e => e.title + (e.allDay ? "" : " at " + clock(e.when))).join(", "));
        const todos = (Planner.todos ?? []).filter(t => !t.done);
        if (todos.length) parts.push(plural(todos.length, "to-do") + " left");
        Halo.say({ key: "evening", icon: "nights_stay", title: asked ? "Your day" : "Wrapping up the day", text: parts.join(" · ") || "A quiet day. Nothing waiting for tomorrow.",
                   level: asked ? "asked" : "important", duration: 16000,
                   speak: (asked ? "" : "Time to wrap up. ") + parts.slice(0, 3).join(". ") + ".",
                   actions: [{ label: "Plan tomorrow", icon: "event_note", run: () => { Planner.open = true; } },
                             { label: "Journal", icon: "auto_stories", run: () => HaloExtras.journal() },
                             Focus.mode !== "sleep" ? { label: "Sleep mode", icon: "bedtime", run: () => Focus.set("sleep") } : null].concat(catchUpActions(s)).filter(a => a) });
    }

    IpcHandler {
        target: "brief"
        function morning(): void { root.morning(true); }
        function away(): void { root.away(true); }
        function evening(): void { root.evening(true); }
        // Dev only (LUMEN_DEV): pretend you were away for n minutes
        function awayFor(min: int): void { if (Quickshell.env("LUMEN_DEV") === "1") { root.awayFrom = Date.now() - min * 60000; root.away(false); } }
    }
}
