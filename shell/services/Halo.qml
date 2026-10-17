pragma Singleton
// Halo, in person — the character around Lumen's assistant (services/Ai.qml
// does the answering). A living ring that sits beside the island's clock, and
// speaks up only when it's worth it:
//
//   say(card)      a Halo card in the island (and, if you want, out loud):
//                  { key, icon?, title, text, tone: normal|happy|concerned,
//                    level: urgent|important|chatter|asked, actions: [{ label,
//                    icon, run }], speak?: string | false, duration? }
//   chattiness     silent     only urgent things (and answers to you)
//                  helpful    + things you'd want to know (default)
//                  companion  + greetings and small check-ins
//   quiet          on a call, in a game, presenting, fullscreen, Focus, Do Not
//                  Disturb, locked: cards wait and come back as one summary
//
//   handle(text)   Jarvis-style requests that Lumen can simply do: "turn on
//                  dark mode", "volume 40", "timer 10 min", "remind me at 9
//                  to call mum", "what did I miss", "how's my computer".
//                  Anything else goes to the model. Destructive things
//                  (shut down, log out…) always ask first.
//
// Mood (what the ring shows) follows what's happening: listening, thinking,
// speaking, concerned (the doctor is worried), sleeping (quiet hours), rest.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root

    // ── who it is ──
    readonly property bool present: Persist.data.haloPresence ?? true
    readonly property string name: (Persist.data.haloName ?? "").trim() || "Halo"
    readonly property string character: Persist.data.haloCharacter ?? "friendly"
    readonly property string chattiness: Persist.data.haloChattiness ?? "helpful"
    property string firstName: ""
    readonly property string you: (Persist.data.haloCall ?? "").trim() || firstName
    Process {
        running: true
        command: ["sh", "-c", 'getent passwd "$(id -un)" | cut -d: -f5 | cut -d, -f1']
        stdout: StdioCollector { onStreamFinished: root.firstName = (text.trim().split(/\s+/)[0] ?? "") }
    }
    // How it talks, for the model (added to Halo's system prompt)
    readonly property string style: ({
        calm: "Speak plainly and briefly, with no exclamation marks or small talk.",
        friendly: "Be warm and encouraging, but brief.",
        jarvis: "Speak like a composed, quietly witty butler-assistant (in the spirit of JARVIS): crisp, polite, the occasional dry remark, never verbose. Don't call the user sir."
    })[character] ?? ""

    // ── quiet ──
    readonly property string quietWhy: Meeting.live ? "a call"
        : (GameMode.on || Context.kind === "game") ? "a game"
        : Context.presenting ? "presenting"
        : Context.fullscreen ? "fullscreen"
        : ["deep", "study", "work", "sleep"].includes(Focus.mode) ? "Focus"
        : Notifications.dnd ? "Do Not Disturb"
        : Lock.locked ? "locked" : ""
    readonly property bool quiet: quietWhy !== ""

    // ── mood ──
    property string flash: ""           // happy / concerned, for a moment
    function react(m, ms) { flash = m; flashTimer.interval = ms ?? 2400; flashTimer.restart(); }
    Timer { id: flashTimer; onTriggered: root.flash = "" }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property bool lateNight: clock.date.getHours() >= 1 && clock.date.getHours() < 6
    readonly property string mood: Voice.listening ? "listening"
        : (Ai.busy && Ai.phase !== "writing") || Voice.transcribing ? "thinking"
        : Voice.speaking || (Ai.busy && Ai.phase === "writing") ? "speaking"
        : flash !== "" ? flash
        : Doctor.worried ? "concerned"
        : (Focus.mode === "sleep" || Notifications.dnd || lateNight) ? "sleeping" : "rest"

    // When a Halo card leaves the island, the ring hops back into its seat by the clock
    property real cardClosedAt: 0
    property bool _cardShown: false
    Connections {
        target: Island
        function onActiveChanged() {
            const now = Island.active?.kind === "halo";
            if (root._cardShown && !now) root.cardClosedAt = Date.now();
            root._cardShown = now;
        }
    }

    // Little signs of life: it's pleased when something you waited for arrives
    Connections { target: Downloads; function onDone() { root.react("happy", 1800); } }
    Connections { target: Battery; function onPluggedInChanged() { if (Battery.pluggedIn && Island.ready) root.react("happy", 1600); } }
    Connections { target: Countdown; function onActiveChanged() { if (!Countdown.active && Island.ready) root.react("happy", 1600); } }

    // ── speaking up ──
    property var held: []               // cards that waited while it was quiet
    property var log: []                // what Halo said lately (newest last), for the panel
    function allowed(level) {
        if (level === "urgent" || level === "asked") return true;
        if (chattiness === "silent") return false;
        if (chattiness === "helpful") return level !== "chatter";
        return true;
    }
    function say(card) {
        const level = card.level ?? "important";
        if (!allowed(level)) return;
        card.time = Date.now();
        card.duration = card.duration ?? 9000;
        // An answer to something you asked, with the panel open: it goes there
        if (level === "asked" && Ai.open) {
            Ai.note(card);
            if (card.tone === "happy") react("happy", 2600);
            if (card.speak !== false && Voice.wanted) Voice.say(card.speak ?? [card.title, card.text].filter(x => x).join(". "));
            return;
        }
        if (quiet && level !== "urgent" && level !== "asked" && !(level === "important" && card.throughQuiet)) {
            held = held.filter(c => c.key !== card.key).concat([card]).slice(-12);
            return;
        }
        log = log.filter(c => c.key !== card.key).concat([card]).slice(-20);
        Island.push({ kind: "halo", key: "halo:" + (card.key ?? "say"), priority: level === "urgent" ? Island.priority.notification : Island.priority.system,
                      duration: card.duration ?? 9000, queueable: true, force: true, data: card });
        if (card.tone === "happy") react("happy", 2600);
        else if (card.tone === "concerned") react("concerned", 2600);
        if (card.speak !== false) Voice.say(card.speak ?? [card.title, card.text].filter(x => x).join(". "));
    }
    function forget(key) { log = log.filter(c => c.key !== key); held = held.filter(c => c.key !== key); }
    // Back from quiet: what waited, as one card
    onQuietChanged: if (!quiet && held.length) backTimer.restart()
    Timer {
        id: backTimer
        interval: 2500
        onTriggered: {
            if (root.quiet || !root.held.length) return;
            const h = root.held;
            root.held = [];
            if (h.length === 1) { root.say(h[0]); return; }
            root.log = root.log.concat(h).slice(-20);
            root.say({ key: "held", icon: "inbox", title: h.length + " things while you were busy",
                       text: h.map(c => c.title).join(" · "), level: "important",
                       actions: [{ label: "Show", icon: "auto_awesome", run: () => Ai.show() }] });
        }
    }

    // ── a few lines in its own voice ──
    function greeting() {
        const h = clock.date.getHours();
        const part = h < 5 ? "evening" : h < 12 ? "morning" : h < 17 ? "afternoon" : "evening";
        const n = you ? ", " + you : "";
        if (character === "calm") return "Good " + part + n + ".";
        if (character === "jarvis") return "Good " + part + n + ". Everything's running as it should.";
        return (part === "morning" ? "Morning" : "Good " + part) + n + "!";
    }
    function done(what) {
        if (character === "calm") return what;
        if (character === "jarvis") return ["Done — ", "Very good — ", "Taken care of — "][Math.floor(Math.random() * 3)] + what.charAt(0).toLowerCase() + what.slice(1);
        return "Got it — " + what.charAt(0).toLowerCase() + what.slice(1);
    }

    // ── Jarvis: things Lumen can simply do ──
    // Returns null (not mine: ask the model) or { ok, title, text, glyph, ask?, run? }
    function intent(raw) {
        let q = raw.trim().replace(/[.!?]+$/, "");
        const lower = q.toLowerCase();
        // Halo's own abilities
        if (/^(what did i miss|catch me up|anything new|while i was away|what happened)\b/i.test(lower))
            return { glyph: "inbox", title: "Catching you up", own: () => Brief.away(true) };
        if (/^(wrap ?up|how was my day|end of (the )?day|summari[sz]e (my|the) day|day summary)\b/i.test(lower))
            return { glyph: "nights_stay", title: "Your day", own: () => Brief.evening(true) };
        if (/^(good morning|brief me|morning brief|what'?s (on )?today|plan for today)\b/i.test(lower))
            return { glyph: "wb_sunny", title: "Today", own: () => Brief.morning(true) };
        if (/^(how'?s|how is|check|is) (my |the )?(computer|laptop|system|pc|machine|battery)\b|^(is anything|what'?s) (wrong|slowing)|^why is (it|my (computer|laptop)) (slow|hot|loud)|^health check/i.test(lower))
            return { glyph: "stethoscope", title: "Checking", own: () => Doctor.checkNow(true) };
        if (/^(circle|search) (to search|my screen|the screen|this)|^what'?s this on (my|the) screen|^lens$/i.test(lower))
            return { glyph: "gesture", title: "Circle to search", own: () => Lens.start() };
        // Reminders: "remind me in 20 min to …", "remind me at 9 (pm) to …"
        let m = /^remind me (?:in |after )?(.+?) (?:to|that|about) (.+)$/i.exec(q) ?? /^remind me to (.+?) (?:in|at|after) (.+)$/i.exec(q);
        if (m) {
            const swap = /^remind me to/i.test(q);
            const when = swap ? m[2] : m[1], what = swap ? m[1] : m[2];
            const at = whenFrom(when);
            if (at > Date.now()) return { glyph: "alarm", title: "I'll remind you " + whenText(at) + " — " + what, plain: true,
                                          run: () => addReminder(at, what) };
        }
        // Everything Lumen's search can do (actions, settings, timers, volume, apps, windows…)
        if (!/^(turn|switch|set|open|launch|start|stop|show|hide|lock|mute|unmute|enable|disable|toggle|play|pause|resume|next|previous|skip|take|record|go|put|make|close|end|kill|restore|save|dim|brighten|raise|lower|increase|decrease|change|run|timer|volume|vol|brightness|bright|caffeine|awake|stay awake|keep awake|screenshot|night light|dark mode|light mode|wifi|wi-fi|bluetooth|airplane|do not disturb|dnd|focus|sleep|suspend|restart|reboot|shut ?down|power off|log ?out)\b/i.test(lower))
            return null;
        let s = lower.replace(/^(please |can you |could you |hey |ok |okay )+/, "").replace(/ please$/, "");
        const want = /\b(on|enable|start)\b/.test(s) ? true : /\b(off|disable|stop)\b/.test(s) ? false : null;
        s = s.replace(/^(turn|switch) (on|off) (the )?/, "").replace(/^(turn|switch|toggle|enable|disable) (the )?/, "").replace(/ (on|off)$/, "")
             .replace(/^(set|change) (the )?(volume|brightness) (to )?(\d+)%?$/, "$3 $5").replace(/^(open|launch|start) (the )?/, "")
             .replace(/^(go|put) (to )?/, "").replace(/^make (it|the screen) /, "");
        s = s.replace(/\bwi-fi\b/, "wifi").replace(/\bdnd\b/, "do not disturb");
        const res = Search.searchResults(s).filter(r => ["command", "timer", "action", "app", "window"].includes(r.kind) && r.run && r.badge !== "");
        const r = res[0];
        if (!r) return null;
        // a toggle already in the state you asked for
        if (r.kind === "action" && want !== null && (r.badge === "On" || r.badge === "Off") && (r.badge === "On") === want)
            return { glyph: r.glyph ?? "check", title: r.title + " is already " + (want ? "on" : "off"), already: true };
        if (r.kind === "action" && want !== null && r.badge !== "On" && r.badge !== "Off" && r.group === "Settings") return null;
        return { glyph: r.glyph ?? "bolt", icon: r.icon ?? "", title: r.title, run: () => r.run(), ask: !!r.destructive, kind: r.kind, doneTitle: doneTitle(r) };
    }
    // What was done, said naturally: "Start a 25:00 timer" → "25:00 timer started"
    function doneTitle(r) {
        const t = r.title;
        let m;
        if ((m = /^Start a (.+) timer$/.exec(t))) return m[1] + " timer started";
        if (/^Start a stopwatch$/.test(t)) return "Stopwatch started";
        if ((m = /^Set (volume|brightness) to (.+)$/.exec(t))) return m[1].charAt(0).toUpperCase() + m[1].slice(1) + " at " + m[2];
        if ((m = /^Stay awake (.+)$/.exec(t))) return "Staying awake " + m[1];
        if (r.kind === "app") return "Opening " + t;
        if (r.kind === "window") return "Switched to " + t;
        if (r.kind === "action" && (r.badge === "On" || r.badge === "Off")) return t + (r.badge === "Off" ? " on" : " off");
        return t;
    }
    // "20 min" · "an hour" · "9" · "9 pm" · "21:30" · "tomorrow 8am" → ms epoch (0 if unreadable)
    function whenFrom(t) {
        t = t.trim().toLowerCase().replace(/^at /, "");
        const rel = Countdown.parse(t.replace(/^an? /, "1 ").replace(/^half an hour$/, "30m"));
        if (rel > 0 && !/^\d{1,2}(:\d{2})?\s*(am|pm)?$/.test(t)) return Date.now() + rel;
        const m = /^(tomorrow )?(\d{1,2})(?::(\d{2}))?\s*(am|pm)?$/.exec(t);
        if (!m) return 0;
        let h = +m[2]; const min = +(m[3] ?? 0);
        if (m[4] === "pm" && h < 12) h += 12;
        if (m[4] === "am" && h === 12) h = 0;
        const now = new Date();
        let d = new Date(now.getFullYear(), now.getMonth(), now.getDate() + (m[1] ? 1 : 0), h, min);
        if (!m[4] && !m[1] && h <= 12 && d.getTime() <= now.getTime()) d = new Date(d.getTime() + 12 * 3600000);   // "at 9" in the evening means 9 pm
        if (d.getTime() <= now.getTime()) d = new Date(d.getTime() + 86400000);
        return d.getTime();
    }
    function whenText(at) {
        const mins = Math.round((at - Date.now()) / 60000);
        if (mins < 90) return "in " + Math.max(1, mins) + " min";
        return Planner.whenLabel(at, false).replace(/^Today · /, "at ").replace(" · ", " at ").replace(/^Tomorrow/, "tomorrow");
    }
    // Do it (or ask first). Answers in the panel when it's open, else as a card.
    // Returns true when Halo handled the request itself.
    function handle(raw, where) {
        const it = intent(raw);
        if (!it) return false;
        if (it.own) { it.own(); return true; }
        const card = { key: "act", icon: it.glyph, title: it.title, level: "asked" };
        if (it.already) { card.tone = "normal"; card.speak = it.title; }
        else if (it.ask) {
            card.title = it.title + "?";
            card.text = "Nothing happens until you say so.";
            card.tone = "concerned";
            card.duration = 15000;
            card.actions = [{ label: it.title, icon: it.glyph, run: it.run }, { label: "Cancel", icon: "close", run: () => {} }];
        } else {
            it.run();
            card.title = it.plain ? it.title : done(it.doneTitle ?? it.title);
            card.tone = "happy";
            card.duration = 3500;
        }
        say(card);
        return true;
    }

    // ── talking to it (Super+Alt+H, or the mic in the panel) ──
    // The island shows it live: listening (the ring follows your voice) →
    // what you said → the answer, spoken if you want; "Open in Halo" continues.
    property string heard: ""
    property bool session: false        // a spoken question is being answered in the island
    function live(extra) {
        Island.push(Object.assign({ kind: "halo", key: "halo:live", priority: Island.priority.system, duration: 25000, force: true,
                                    data: { key: "live", live: true } }, extra ?? {}));
    }
    function talk() {
        if (Voice.listening) { Voice.stopListening(); return; }
        if (Ai.open) { Voice.listen(); return; }          // the panel shows it itself
        heard = "";
        Ai.prepare();
        Voice.listen();
        if (Voice.listening) live();
    }
    Connections {
        target: Voice
        function onHeard(text) { root.ask(text); }
        function onMissed(why) {
            if (why === "cancelled") { Island.dismiss(); return; }
            const card = why === "no-stt"
                ? { key: "live", icon: "mic_off", title: "I can't hear yet", text: "Voice needs whisper.cpp — Settings → Halo shows how (it all stays on this computer).",
                    level: "asked", duration: 7000, actions: [{ label: "Set it up", icon: "settings", run: () => SettingsState.launch("ai") }] }
                : { key: "live", icon: "hearing", title: why === "nothing" ? "I didn't catch anything" : "I couldn't listen", text: why === "nothing" ? "" : why, level: "asked", duration: 2500, speak: false };
            if (Ai.open) Ai.error = card.title + (card.text ? " — " + card.text : "");
            else root.say(card);
        }
    }
    function ask(text) {
        heard = text;
        if (Ai.open) { Ai.send(text); return; }
        if (handle(text, "island")) return;
        if (!Ai.configured) {
            say({ key: "live", icon: "psychology", title: "“" + text + "”", text: "To answer that I need a brain — choose one in Settings → Halo.", level: "asked",
                  actions: [{ label: "Settings → Halo", icon: "settings", run: () => SettingsState.launch("ai") }] });
            return;
        }
        session = true;
        live({ duration: 120000 });
        Ai.send(text);
    }
    // The answer to a spoken question, in the island (and aloud)
    function answered(answer) {
        session = false;
        const plain = Voice.speakable(answer) || answer.replace(/\s+/g, " ").slice(0, 280);
        const ms = Math.max(8000, Math.min(20000, plain.length * 60));
        Island.push({ kind: "halo", key: "halo:live", priority: Island.priority.system, duration: ms, force: true,
                      data: { key: "live", icon: "auto_awesome", title: "“" + heard + "”", text: plain, answer, duration: ms,
                              actions: [{ label: "Open in Halo", icon: "open_in_full", run: () => Ai.show() },
                                        { label: "Copy", icon: "content_copy", run: () => Ai.copy(answer) }] } });
        Voice.say(answer);
    }

    // ── reminders (kept across restarts) ──
    readonly property var reminders: Persist.data.haloReminders ?? []
    function addReminder(at, text) { Persist.data.haloReminders = reminders.concat([{ at, text }]).sort((a, b) => a.at - b.at); }
    function removeReminder(i) { Persist.data.haloReminders = reminders.filter((_, j) => j !== i); }
    Timer {
        interval: 15000; repeat: true; triggeredOnStart: true
        running: Persist.automates && root.reminders.length > 0
        onTriggered: {
            const now = Date.now(), due = root.reminders.filter(r => r.at <= now);
            if (!due.length) return;
            Persist.data.haloReminders = root.reminders.filter(r => r.at > now);
            for (const r of due) {
                Sounds.play("alarm");
                root.say({ key: "remind:" + r.at, icon: "alarm", title: "Reminder", text: r.text, level: "urgent", duration: 20000,
                           speak: (root.you ? root.you + ", " : "") + "a reminder: " + r.text,
                           actions: [{ label: "In 10 minutes", icon: "snooze", run: () => root.addReminder(Date.now() + 600000, r.text) }, { label: "Done", icon: "done", run: () => {} }] });
            }
        }
    }

    IpcHandler {
        target: "halo"
        function say(title: string, text: string): void { root.say({ key: "ipc", icon: "auto_awesome", title, text, level: "asked" }); }
        function handle(text: string): bool { return root.handle(text, "island"); }
        function mood(): string { return root.mood; }
        function state(): string { return JSON.stringify({ mood: root.mood, quiet: root.quietWhy, orbHovered: Island.orbHovered, islandHovered: Island.hovered, variant: Island.variant }); }
        function react(m: string): void { root.react(m, 3000); }
    }
}
