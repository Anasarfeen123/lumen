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
import Quickshell.Wayland
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
        : HaloExtras.sharing ? "sharing your screen"
        : Lock.locked ? "locked" : ""
    readonly property bool quiet: quietWhy !== ""

    // ── mood ──
    property string flash: ""           // happy / concerned, for a moment
    function react(m, ms) { flash = m; flashTimer.interval = ms ?? 2400; flashTimer.restart(); }
    Timer { id: flashTimer; onTriggered: root.flash = "" }
    SystemClock { id: clock; precision: SystemClock.Minutes }
    readonly property bool lateNight: clock.date.getHours() >= 1 && clock.date.getHours() < 6
    readonly property string mood: Voice.listening ? "listening"
        : (Ai.busy && Ai.phase !== "writing") || Voice.transcribing || Agent.thinking ? "thinking"
        : Voice.speaking || (Ai.busy && Ai.phase === "writing") ? "speaking"
        : flash !== "" ? flash
        : Doctor.worried ? "concerned"
        : (Focus.mode === "sleep" || Notifications.dnd || lateNight || idleMon.isIdle) ? "sleeping" : "rest"
    // dozes off when you've been away from the keyboard a few minutes
    IdleMonitor { id: idleMon; timeout: 180; respectInhibitors: true; enabled: root.present }

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
    property var capture: null          // the agent reading what a card would say, without showing it
    function say(card) {
        if (capture) { capture(card); return; }
        // talking with Halo (the voice sheet): its answers go there
        if (Converse.open && (card.level ?? "important") !== "chatter" && card.key !== "hands") { card.time = Date.now(); Converse.card(card); return; }
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
        // Too long for the island: one tap shows all of it in Halo
        if (((card.text ?? "").split("\n").length > 4 || (card.text ?? "").length > 240) && !(card.actions ?? []).some(a => a?.full)) {
            const full = Object.assign({}, card);
            card.actions = (card.actions ?? []).concat([{ label: "Show all", icon: "open_in_full", full: true, run: () => { Ai.show(); Ai.note(full); } }]);
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
        // keep names as they are ("Do Not Disturb on"); lowercase a plain first word
        return "Got it — " + (/^[A-Z][a-z]+ [A-Z]/.test(what) ? what : what.charAt(0).toLowerCase() + what.slice(1));
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
        if (/^(let me |i want to |can i )?(draw|annotate|scribble) (on|over) (the |my )?screen|^(screen )?(pen|marker|ink)( mode)?$/i.test(lower))
            return { glyph: "draw", title: "Draw on the screen", own: () => { DrawState.open = true; } };
        if (/^(circle|search) (to search|my screen|the screen|this)|^what'?s this on (my|the) screen|^lens$/i.test(lower))
            return { glyph: "gesture", title: "Circle to search", own: () => Lens.start() };
        // "Watch me" → a workflow from how you set things up
        const rec = Recorder.intent(q);
        if (rec) return rec;
        // Memory: "remember that …", "what do you remember", "forget …"
        let mm;
        if ((mm = /^(?:please )?remember (?:that |this: ?)?(.{3,300})$/i.exec(q)) && !/^remember me\b/i.test(q))
            return { glyph: "bookmark_add", title: "I'll remember that", plain: true, run: () => root.remember(mm[1]) };
        if (/^(what do you (remember|know) about me|what have i told you|show (my )?memor(y|ies)|my memor(y|ies))$/.test(lower))
            return { glyph: "bookmarks", title: "What I remember", own: () => root.say({ key: "memory", icon: "bookmarks", title: memory.length ? "What I remember (" + memory.length + ")" : "Nothing yet",
                     text: memory.length ? memory.map(x => "• " + x.text).join("\n") : "Tell me “remember that my roll number is …” and I'll keep it — you can see and delete everything in Settings → Halo.",
                     level: "asked", duration: 15000, actions: memory.length ? [{ label: "Manage", icon: "settings", run: () => SettingsState.launch("ai") }] : [] }) };
        if ((mm = /^forget (?:that |about |the fact that )?(.+)$/i.exec(q))) {
            const what = mm[1].toLowerCase();
            if (/^(everything|all of it|all)$/.test(what))
                return { glyph: "delete_sweep", title: "Forget everything I remember", ask: true, run: () => { Persist.data.haloMemory = []; } };
            const hit = memory.find(x => x.text.toLowerCase().includes(what)) ?? memory.find(x => what.split(/\s+/).filter(w => w.length > 3).some(w => x.text.toLowerCase().includes(w)));
            return hit ? { glyph: "bookmark_remove", title: "Forgotten: " + hit.text, plain: true, run: () => root.forgetItem(hit) }
                       : { glyph: "bookmark", title: "I don't remember anything like that", already: true };
        }
        // Routines and watches: "every weekday at 8:30, …", "when I …, …", "tell me when …"
        const routine = Routines.intent(q);
        if (routine) return routine;
        // Workflows: "save that as study mode", "run study mode"
        if ((mm = /^(?:save|remember|keep) (?:that|this|it|those steps) as (?:a |my )?(?:workflow )?["“]?(.+?)["”]?$/i.exec(q)))
            return Agent.lastSteps().length ? { glyph: "playlist_add", title: "Saved “" + mm[1] + "”", plain: true, run: () => Agent.saveWorkflow(mm[1]) }
                                            : { glyph: "playlist_add", title: "Nothing to save yet — ask me to do something first", already: true };
        if ((mm = /^(?:run|do|start|play|replay|launch)(?: the| my)? (.+?)(?: workflow)?$/i.exec(q)) && Agent.workflow(mm[1]))
            return { glyph: "playlist_play", title: "Running “" + Agent.workflow(mm[1]).name + "”", own: () => Agent.replay(mm[1]) };
        if (/^(what are |show |list )?(my )?workflows$/.test(lower))
            return { glyph: "playlist_play", title: "Workflows", own: () => root.say({ key: "workflows", icon: "playlist_play", title: Object.keys(Persist.data.haloWorkflows ?? {}).length ? "Your workflows" : "No workflows yet",
                     text: Object.keys(Persist.data.haloWorkflows ?? {}).map(n => "• " + n + " — " + (Persist.data.haloWorkflows[n] ?? []).map(s => s.say).join(", ")).join("\n") || "Ask me to do a job, then say “save that as <name>”.",
                     level: "asked", duration: 15000 }) };
        // Quiz me on a topic — your matching note comes along
        if ((mm = /^(?:quiz|test) me(?: on| about)? (.+)$/i.exec(q))) {
            const topic = mm[1].replace(/^(my |the )/i, "").replace(/ notes?$/i, "");
            const words = topic.toLowerCase().split(/\s+/).filter(w => w.length > 1);
            const note = Notes.all.find(n => words.every(w => n.title.toLowerCase().includes(w))) ?? Notes.all.find(n => words.some(w => w.length > 3 && n.title.toLowerCase().includes(w)));
            return { glyph: "quiz", title: "Quiz on " + topic, own: () => {
                if (note) Ai.files = [Notes.pathOf(note.file)];
                Ai.show();
                Ai.send("/quiz " + topic + (note ? " (from my note “" + note.title + "”)" : ""));
            } };
        }
        // Calendars and email
        const acc = Accounts.intent(q);
        if (acc) return acc;
        // College (AmazeCC): next class, attendance, skipping, marks, FAT targets, exams
        const college = HaloCollege.intent(q);
        if (college) return college;
        // Reminders: "remind me in 20 min to …", "remind me at 9 (pm) to …"
        let m = /^remind me (?:in |after )?(.+?) (?:to|that|about) (.+)$/i.exec(q) ?? /^remind me to (.+?) (?:in|at|after) (.+)$/i.exec(q);
        if (m) {
            const swap = /^remind me to/i.test(q);
            const when = swap ? m[2] : m[1], what = swap ? m[1] : m[2];
            const at = whenFrom(when);
            if (at > Date.now()) return { glyph: "alarm", title: "I'll remind you " + whenText(at) + " — " + what, plain: true,
                                          run: () => addReminder(at, what) };
        }
        // Web pages, tidying, repairs, battery, updates, music, journal, lectures, birthdays
        const ex = HaloExtras.intent(q);
        if (ex) return ex;
        // Hands, windows, music, quick answers, files, reading aloud
        const extra = more(q, lower);
        if (extra) return extra;
        // Everything Lumen's search can do (actions, settings, timers, volume, apps, windows…)
        if (!/^(turn|switch|set|open|launch|start|stop|show|hide|lock|mute|unmute|enable|disable|toggle|play|pause|resume|next|previous|skip|take|record|go|put|make|close|end|kill|restore|save|dim|brighten|raise|lower|increase|decrease|change|run|timer|volume|vol|brightness|bright|caffeine|awake|stay awake|keep awake|screenshot|night light|dark mode|light mode|wifi|wi-fi|bluetooth|airplane|do not disturb|dnd|focus|sleep|suspend|restart|reboot|shut ?down|power off|log ?out)\b/i.test(lower))
            return null;
        let s = lower.replace(/^(please |can you |could you |hey |ok |okay )+/, "").replace(/ please$/, "");
        const want = /\bunmute\b/.test(s) ? false : /\bmute\b/.test(s) ? true
                   : /\b(on|enable|start)\b/.test(s) ? true : /\b(off|disable|stop)\b/.test(s) ? false : null;
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
    // ── more things Halo can simply do ──
    function hyprDo(cmd) { Quickshell.execDetached(["hyprctl", "dispatch", cmd]); }
    function answer(icon, title, text) { return { glyph: icon, title, own: () => root.say({ key: "fact", icon, title, text: text ?? "", level: "asked", tone: "normal", duration: 7000 }) }; }
    function more(q, lower) {
        let m;
        const trimThe = t => t.replace(/^(the|a|an|that|this) /i, "").replace(/ (button|link|tab|icon|option)$/i, "").replace(/^["“']|["”']$/g, "").trim();
        // ── timers, said naturally ("set a timer for 10 minutes", "a 25 minute timer") ──
        if ((m = /^(?:set|start|put on|make)(?: me)?(?: a| an)? (?:timer|countdown) (?:for |of )?(.+)$/i.exec(lower)) || (m = /^(?:set|start)(?: a| an)? (.+?) (?:timer|countdown)$/i.exec(lower))) {
            const ms = Countdown.parse(m[1].replace(/^half an? hour$/, "30 min").replace(/^(a|an|one) (hour|minute)/, "1 $2").replace(/\bminutes?\b/, "min").replace(/\bseconds?\b/, "s").replace(/\bhours?\b/, "h"));
            if (ms > 0) return { glyph: "timer", title: Countdown.fmt(ms) + " timer started", plain: true, run: () => Countdown.startTimer(ms, "") };
        }
        // ── hands: keys first ("press ctrl+s", "hit enter"), then clicks, pointing, scrolling, typing
        if ((m = /^(?:press|hit|tap) ((?:(?:ctrl|control|alt|shift|super|win|meta)\s*\+\s*)*(?:[a-z0-9]|f\d{1,2}|enter|return|esc|escape|tab|space|backspace|delete|up|down|left|right|home|end|page ?up|page ?down))$/i.exec(lower)))
            return { glyph: "keyboard", title: "Press " + m[1], own: () => Hands.key(m[1].replace(/page ?up/i, "pageup").replace(/page ?down/i, "pagedown")) };
        if ((m = /^(double[- ]click|right[- ]click|click|tap|press|select)(?: on)? (.+)$/i.exec(q))) {
            const btn = /^double/i.test(m[1]) ? "double" : /^right/i.test(m[1]) ? "right" : "left";
            const what = trimThe(m[2]);
            if (what) return { glyph: "ads_click", title: "Click " + what, own: () => Hands.clickText(what, btn) };
        }
        if ((m = /^(?:point (?:at|to)|where(?:'s| is)|show me where|find on (?:the )?screen|look at) (.+?)(?: on (?:the|my) screen)?$/i.exec(q)))
            return { glyph: "near_me", title: "Pointing at " + trimThe(m[1]), own: () => Hands.pointAt(trimThe(m[1])) };
        if ((m = /^scroll (down|up)(?: (a bit|a little|a lot|more|to the (?:top|bottom)))?$/i.exec(lower))) {
            const amt = !m[2] ? 5 : /bit|little/.test(m[2]) ? 2 : /lot|more/.test(m[2]) ? 12 : 30;
            return { glyph: m[1] === "down" ? "south" : "north", title: "Scroll " + m[1], own: () => Hands.scroll(m[1], amt) };
        }
        if ((m = /^type (?:out |in )?(?:["“](.+)["”]|(.+))$/i.exec(q)))
            return { glyph: "keyboard", title: "Type it", own: () => Hands.type(m[1] ?? m[2]) };
        if (/^(go back|back)$/.test(lower)) return { glyph: "arrow_back", title: "Back", own: () => Hands.key("alt+Left", true) };
        if (/^(go forward|forward)$/.test(lower)) return { glyph: "arrow_forward", title: "Forward", own: () => Hands.key("alt+Right", true) };
        if (/^(refresh|reload)( the page| this| it)?$/.test(lower)) return { glyph: "refresh", title: "Reload", own: () => Hands.key("F5", true) };
        if (/^(new tab|open a new tab)$/.test(lower)) return { glyph: "tab", title: "New tab", own: () => Hands.key("ctrl+t", true) };

        // ── windows and workspaces ──
        if ((m = /^(?:go to|switch to|show) workspace (\d+)$/.exec(lower)))
            return { glyph: "space_dashboard", title: "Workspace " + m[1], doneTitle: "On workspace " + m[1], run: () => hyprDo("hl.dsp.focus({ workspace = " + m[1] + " })") };
        if ((m = /^(?:move|send|put) (?:this|the|my)? ?(?:window|app)? ?to workspace (\d+)$/.exec(lower)))
            return { glyph: "move_group", title: "Moved to workspace " + m[1], plain: true, run: () => hyprDo("hl.dsp.window.move({ workspace = " + m[1] + " })") };
        if (/^(maximi[sz]e|make (it|this) (big|bigger|full))( (this|the|my) window| it)?$/.test(lower))
            return { glyph: "fullscreen", title: "Maximised", plain: true, run: () => hyprDo("hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\" })") };
        if (/^(full ?screen)( (this|the|my) window| it)?$/.test(lower))
            return { glyph: "fullscreen", title: "Fullscreen", plain: true, run: () => hyprDo("hl.dsp.window.fullscreen({ mode = \"fullscreen\", action = \"toggle\" })") };
        if (/^(float|unfloat|pop out|tile)( (this|the|my) window| it)?$/.test(lower))
            return { glyph: "picture_in_picture", title: "Floating or tiled", plain: true, run: () => { hyprDo("hl.dsp.window.float({ action = \"toggle\" })"); hyprDo("hl.dsp.window.center()"); } };
        if (/^(minimi[sz]e|hide|tuck away)( (this|the|my) window| it)?$/.test(lower))
            return { glyph: "minimize", title: "Tucked away (Super+Shift+H brings it back)", plain: true, run: () => hyprDo("hl.dsp.window.move({ workspace = \"special:minimized\", follow = false })") };
        if (/^close (this|the|my) window$/.test(lower)) {
            const t = Hyprland.activeToplevel?.title ?? "this window";
            return { glyph: "close", title: "Close “" + t.slice(0, 50) + "”", ask: true, run: () => hyprDo("hl.dsp.window.close()") };
        }

        // ── sound ──
        if ((m = /^(un)?mute( the)?( (sound|audio|volume|speakers?|laptop|everything))?$/.exec(lower))) {
            const want = !m[1];
            return Audio.muted === want ? { glyph: want ? "volume_off" : "volume_up", title: "Sound is already " + (want ? "muted" : "on"), already: true }
                                        : { glyph: want ? "volume_off" : "volume_up", title: want ? "Sound muted" : "Sound on", plain: true, run: () => Audio.toggleMute() };
        }
        if ((m = /^(un)?mute( the| my)? (mic|microphone)$/.exec(lower))) {
            const want = !m[1];
            return Audio.micMuted === want ? { glyph: want ? "mic_off" : "mic", title: "Microphone is already " + (want ? "off" : "on"), already: true }
                                           : { glyph: want ? "mic_off" : "mic", title: want ? "Microphone off" : "Microphone on", plain: true, run: () => Audio.toggleMicMute() };
        }
        // ── power and the screen ──
        if (/^(turn |switch )?(on )?(battery|power) saver( mode)?( on)?$|^save (the )?battery$|^(turn on|enable) (battery|power) saver$/.test(lower))
            return Power.saver ? { glyph: "energy_savings_leaf", title: "Battery saver is already on", already: true }
                               : { glyph: "energy_savings_leaf", title: "Battery saver on", plain: true, run: () => Power.saverOn() };
        if (/^(turn |switch )?(off )?(battery|power) saver( mode)? off$|^(turn off|disable) (battery|power) saver$|^balanced( mode)?$/.test(lower))
            return { glyph: "balance", title: "Balanced power", plain: true, run: () => Power.balanced() };
        if (/^(performance|turbo|full power)( mode)?( on)?$/.test(lower))
            return { glyph: "bolt", title: "Performance mode", plain: true, run: () => Power.performance() };
        if (/^(dim|darken)( the)?( screen| display)?( a bit| a little)?$|^(lower|reduce|decrease)( the)? brightness$|^(make )?(the )?screen darker$/.test(lower))
            return { glyph: "brightness_low", title: "Screen dimmed", plain: true, run: () => Brightness.set(Math.max(0.05, (Brightness.value ?? 0.5) - 0.25)) };
        if (/^(brighten|lighten)( the)?( screen| display)?( a bit| a little)?$|^(raise|increase)( the)? brightness$|^(make )?(the )?screen brighter$/.test(lower))
            return { glyph: "brightness_high", title: "Screen brighter", plain: true, run: () => Brightness.set(Math.min(1, (Brightness.value ?? 0.5) + 0.25)) };

        // ── picture in picture ──
        if (/^(picture[- ]in[- ]picture|pip|pop (it|this|the (video|player|window)) out|float (the )?video|mini ?player)( (on|mode))?$/.test(lower))
            return { glyph: "picture_in_picture", title: "Picture in picture", plain: true, run: () => (Media.playing && Pip.playerWindow() ? Pip.popPlayer() : Pip.pop("")) };
        if ((m = /^(?:move|put) (?:the )?(?:pip|video|mini ?player|picture in picture) (?:to )?(?:the )?(top|bottom) (left|right)$/.exec(lower)))
            return { glyph: "picture_in_picture_alt", title: "Moved", plain: true, run: () => Pip.corner((m[1] === "top" ? "t" : "b") + (m[2] === "left" ? "l" : "r")) };
        if (Pip.active && /^(make (it|the (pip|video)) )?(bigger|larger|smaller)$/.test(lower))
            return { glyph: "aspect_ratio", title: /small/.test(lower) ? "Smaller" : "Bigger", plain: true, run: () => Pip.size(/small/.test(lower) ? "smaller" : "bigger") };
        if (Pip.active && /^(put it back|exit (pip|picture in picture)|close (the )?pip|pip off|stop picture in picture)$/.test(lower))
            return { glyph: "close_fullscreen", title: "Back in its place", plain: true, run: () => Pip.back() };
        if ((m = /^(?:stop|pause) (?:the )?music in (\d+) ?(?:min|minutes)$|^sleep timer (?:for )?(\d+)(?: ?min(?:utes)?)?$/.exec(lower)))
            return { glyph: "bedtime", title: "Music stops in " + (m[1] ?? m[2]) + " min", plain: true, run: () => Media.sleepIn(+(m[1] ?? m[2])) };
        // ── music ──
        if (/^(pause|stop)( the)? (music|song|playback|it)$|^pause$/.test(lower) && Media.playing)
            return { glyph: "pause", title: "Paused", plain: true, run: () => Media.toggle() };
        if (/^(play|resume|continue)( the)? (music|song|playback|it)$|^(play|resume)$/.test(lower) && !Media.playing && Media.present)
            return { glyph: "play_arrow", title: "Playing " + (Media.title || "again"), plain: true, run: () => Media.toggle() };
        if (/^(next|skip)( (song|track|this( song)?))?$/.test(lower) && Media.present)
            return { glyph: "skip_next", title: "Next track", plain: true, run: () => Media.next() };
        if (/^(previous|last|go back a)( song| track)$|^previous$/.test(lower) && Media.present)
            return { glyph: "skip_previous", title: "Previous track", plain: true, run: () => Media.previous() };
        if (/^(what'?s|what is) (playing|this song|the song|on)\b/.test(lower))
            return Media.present ? answer("music_note", Media.title || "Something's playing", [Media.artist, Media.playing ? "playing" : "paused"].filter(x => x).join(" · "))
                                 : answer("music_off", "Nothing's playing", "");

        // ── quick answers ──
        if (/^(how much )?battery( left| level| status)?$|^how('?s| is) (the|my) battery$|^(how long will|when will) (the|my) battery/.test(lower)) {
            if (!Battery.available) return answer("power", "No battery", "This computer runs on mains power.");
            const pct = Math.round(Battery.percentage * 100) + "%";
            return answer(Battery.icon, pct + (Battery.pluggedIn ? (Battery.full ? " — full" : " and charging") : ""),
                          Battery.pluggedIn ? (Battery.timeToFull > 0 ? "Full in " + Battery.formatDuration(Battery.timeToFull) : "") : (Battery.forecastText ? "About " + Battery.forecastText + " left at this rate" : ""));
        }
        if (/^(what('?s| is) the )?time( is it)?( now)?$|^what time is it$/.test(lower))
            return answer("schedule", Qt.formatTime(new Date(), Theme.timeFormatFull), Qt.formatDate(new Date(), "dddd d MMMM"));
        if (/^(what('?s| is) )?(the |today'?s )?date( today)?$|^what day is (it|today)$/.test(lower))
            return answer("calendar_today", Qt.formatDate(new Date(), "dddd d MMMM yyyy"), "");
        if (/^(what('?s| is) )?(my |the )?(wi-?fi|network)( name| called)?$|^which wi-?fi\b/.test(lower))
            return answer(Network.ssid ? "wifi" : "wifi_off", Network.ssid || "Not connected to Wi-Fi", "");

        // ── to the phone ──
        if (/^send (that|this|it|the answer) to (my )?phone$/.test(lower)) {
            const t = HaloPhone.lastAnswer();
            return !Link.phone ? { glyph: "mobile_off", title: "No phone linked — Settings → Phone", already: true }
                 : !t ? { glyph: "smartphone", title: "Nothing to send yet", already: true }
                 : { glyph: "send_to_mobile", title: "Sent to " + (Link.phone.name ?? "your phone"), plain: true, run: () => Link.sendText(t) };
        }
        // ── quiet, please ──
        if (/^(stop talking|be quiet|shut up|quiet|shh+|stop speaking|that'?s enough)$/.test(lower))
            return { glyph: "volume_off", title: "Okay", own: () => { Voice.stop(); Voice.cancel(); } };
        // ── reading aloud ──
        if (/^read (this|that|it|the selection|my selection|what i selected|my clipboard|the clipboard)( to me| aloud| out loud)?$/.test(lower))
            return { glyph: "record_voice_over", title: "Reading it", own: () => root.readAloud(/clipboard/.test(lower)) };

        // ── files ──
        if ((m = /^(?:find|search for|look for|open|where(?:'s| is)) (?:my |the )?(?:file |document |pdf |notes? )?(.+?\.(?:pdf|docx?|pptx?|xlsx?|txt|md|png|jpe?g|zip|mp4|mp3|csv|py|c|cpp|java|js))$/i.exec(q))
            ?? (m = /^(?:find|search for|look for) (?:my |the )?(?:file|files|document|pdf|notes?) (?:called |named |about )?(.+)$/i.exec(q)))
            return { glyph: "search", title: "Looking for " + m[1], own: () => root.findFile(m[1]) };
        return null;
    }

    // Read the selection (or clipboard) aloud — even with spoken replies off
    function readAloud(clipboard) { readProc.command = ["sh", "-c", clipboard ? "wl-paste --no-newline 2>/dev/null | head -c 6000" : "wl-paste --primary --no-newline 2>/dev/null | head -c 6000"]; readProc.running = true; }
    Process {
        id: readProc
        stdout: StdioCollector {
            onStreamFinished: {
                const t = text.trim();
                if (!t) { root.say({ key: "fact", icon: "record_voice_over", title: "Nothing to read", text: "Select some text first (or copy it and say “read my clipboard”).", level: "asked" }); return; }
                if (!Voice.canSpeak) { root.say({ key: "fact", icon: "volume_off", title: "I can't speak yet", text: "Install espeak-ng (sudo dnf install espeak-ng).", level: "asked" }); return; }
                Voice.say(t, true);
            }
        }
    }
    // Find files in your home by name (fd), newest first
    function findFile(name) {
        const words = name.trim().split(/\s+/).filter(w => w).map(w => w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&"));
        fileProc.want = name;
        fileProc.command = ["sh", "-c", 'cd "$HOME" && fd -i -t f --max-results 40 --exclude ".*" -- "$1" 2>/dev/null | head -40 | while read -r f; do printf "%s\t%s\n" "$(stat -c %Y "$f" 2>/dev/null)" "$HOME/$f"; done | sort -rn | head -4 | cut -f2',
                            "sh", words.join(".*")];
        fileProc.running = true;
    }
    Process {
        id: fileProc
        property string want: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const files = text.split("\n").filter(f => f);
                if (!files.length) { root.say({ key: "fact", icon: "search_off", title: "No file called “" + fileProc.want + "”", text: "I looked through your home folder (hidden folders skipped).", level: "asked", tone: "concerned" }); return; }
                const nice = f => f.replace(Quickshell.env("HOME"), "~");
                root.say({ key: "files", icon: "description", title: files.length === 1 ? files[0].replace(/.*\//, "") : "Found " + files.length + " files",
                          text: files.map(nice).join("\n"), level: "asked", duration: 15000,
                          actions: files.slice(0, 3).map(f => {
                                       const name = f.replace(/.*\//, ""), dup = files.filter(g => g.replace(/.*\//, "") === name).length > 1;
                                       const dir = f.replace(/\/[^\/]*$/, "").replace(/.*\//, "");
                                       return { label: "Open " + name.slice(0, 22) + (dup ? " · " + dir.slice(0, 14) : ""), icon: "open_in_new", run: () => Qt.openUrlExternally("file://" + f) };
                                   })
                                   .concat([{ label: "Show in folder", icon: "folder_open", run: () => Quickshell.execDetached(["xdg-open", files[0].replace(/\/[^\/]*$/, "")]) },
                                            { label: "Ask about it", icon: "auto_awesome", run: () => Ai.askAboutFiles([files[0]], "file") }]) });
            }
        }
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
        if (Converse.open) return;              // the voice sheet shows it
        Island.push(Object.assign({ kind: "halo", key: "halo:live", priority: Island.priority.system, duration: 25000, force: true,
                                    data: { key: "live", live: true } }, extra ?? {}));
    }
    function talk() {
        if (!Ai.open) { Converse.show(); return; }    // the voice sheet (Ai.open: the panel's own mic)
        if (Voice.listening) { Voice.stopListening(); return; }
        if (Ai.open) { Voice.listen(); return; }          // the panel shows it itself
        heard = "";
        Ai.prepare();
        Voice.listen();
        if (Voice.listening) live();
    }
    Connections {
        target: Voice
        // "hey halo, …" says it all at once; "hey halo" alone: Halo listens for the rest
        function onWoke(rest) { if (rest.length > 2) Converse.say(rest); else Converse.show(); }
        function onHeard(text) { if (!Converse.open) root.ask(text); }
        function onMissed(why) {
            if (Converse.open) return;
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
        if (Ai.configured && Agent.multi(text)) { Agent.start(text, "island"); return; }
        if (handle(text, "island")) return;
        if (Ai.configured && Agent.wants(text)) { Agent.start(text, "island"); return; }
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
        if (Converse.open) { Converse.answered(answer); return; }
        const plain = Voice.speakable(answer) || answer.replace(/\s+/g, " ").slice(0, 280);
        const ms = Math.max(8000, Math.min(20000, plain.length * 60));
        Island.push({ kind: "halo", key: "halo:live", priority: Island.priority.system, duration: ms, force: true,
                      data: { key: "live", icon: "auto_awesome", title: "“" + heard + "”", text: plain, answer, duration: ms,
                              actions: [{ label: "Open in Halo", icon: "open_in_full", run: () => Ai.show() },
                                        { label: "Copy", icon: "content_copy", run: () => Ai.copy(answer) }] } });
        Voice.say(answer);
    }

    // ── memory: what you asked Halo to keep (Settings → Halo shows and deletes it) ──
    readonly property var memory: Persist.data.haloMemory ?? []
    function remember(text) {
        text = text.trim().replace(/[.]+$/, "");
        if (!text) return;
        Persist.data.haloMemory = memory.filter(x => x.text.toLowerCase() !== text.toLowerCase()).concat([{ text, at: Date.now() }]).slice(-60);
    }
    function forgetItem(item) { Persist.data.haloMemory = memory.filter(x => x.text !== item.text); }
    // for the model: only if you allow it (Settings → Halo → Memory)
    readonly property string memoryText: (Persist.data.haloUseMemory ?? true) && memory.length
        ? "Things the user asked you to remember:\n" + memory.map(x => "- " + x.text).join("\n") : ""

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
        // what Halo would do with it, without doing it
        function check(text: string): string { const it = root.intent(text); return it ? (it.ask ? "asks: " : "") + (it.doneTitle ?? it.title) : "(not mine — the model)"; }
        function mood(): string { return root.mood; }
        function state(): string { return JSON.stringify({ mood: root.mood, quiet: root.quietWhy, orbHovered: Island.orbHovered, islandHovered: Island.hovered, variant: Island.variant }); }
        function react(m: string): void { root.react(m, 3000); }
    }
}
