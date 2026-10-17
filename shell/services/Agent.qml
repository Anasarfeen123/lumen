pragma Singleton
// Halo, acting: a goal in plain words → steps with Lumen's tools → an answer.
//   "start a 50 minute study session and tell me my next class"
//   "find my DBMS notes and summarise them"
//   "open settings and point at Wi-Fi"
//   "add a todo for the OS lab record and remind me at 9"
//
// The model (Halo's own: Ollama, Claude, …) picks one tool at a time as JSON;
// each step shows live in Halo (or in the island, when the step needs the
// screen or you asked by voice). Rules that don't bend:
//   • reading and Lumen's own reversible actions just happen
//   • clicks, keys and typing ask through Halo's hands (next to the spot);
//     shell commands and anything destructive ask in the step itself
//   • at most 8 steps; Stop (or Esc) any time; nothing is remembered after
// Tools are below (tools: name, what the model is told, how it runs).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root
    readonly property bool enabled: Persist.data.haloAgent ?? true

    // ── the runs (the panel shows them by id; only one runs at a time) ──
    property var runs: ({})             // id → { goal, steps: [{ tool, say, icon, state, result }], answer, state, where }
    property string current: ""
    readonly property var active: runs[current] ?? null
    readonly property bool running: active?.state === "running" || active?.state === "waiting"
    readonly property bool thinking: brain.running
    property var history: []            // the model conversation for the current run
    property int count: 0
    readonly property int maxSteps: 8

    function update(fn) {
        if (!current) return;
        const r = Object.assign({}, runs[current]);
        r.steps = (r.steps ?? []).slice();
        fn(r);
        const all = Object.assign({}, runs); all[current] = r; runs = all;
        if (r.where === "island") Halo.live({ duration: 120000 });
    }

    // Does this sound like a job (rather than a question)?
    function wants(text) {
        if (!enabled) return false;
        const t = text.trim().toLowerCase().replace(/^(please|hey halo|halo|ok|okay|can you|could you|would you)[ ,]+/g, "");
        if (/^\/agent\b/.test(t)) return true;
        if (/^(what|why|how|who|when|where|which|explain|is|are|does|do|did|should|tell me about|define)\b/.test(t) && !/\band (then )?(open|start|add|set|remind|make|create|put|send|play|switch|close|move)\b/.test(t)) return false;
        return /^(open|set ?up|prepare|plan|schedule|add|create|make|start|remind|find|search|look up|check|move|close|switch|turn|put|send|message|organi[sz]e|tidy|clean up|help me (study|prepare|plan|get ready|organi[sz]e|focus)|get (me )?ready|go to|show me|write (a |me a )?note|note down|take a note|summari[sz]e (my|the)|read (my|the)|launch|play|book|draft|text|copy|save)\b/.test(t)
            || /\b(and then|then|after that)\b/.test(t);
    }

    // Several things in one breath ("… and …", "then"): the agent, before any shortcut
    function multi(text) { return enabled && /\b(and|then|after that|also)\b/i.test(text) && wants(text); }
    function start(goal, where) {
        goal = goal.replace(/^\/agent\s*/i, "").trim();
        if (!goal) return;
        if (running) stop();
        const id = "run" + (++count);
        const r = Object.assign({}, runs);
        r[id] = { goal, steps: [], answer: "", state: "running", where: where ?? (Ai.open ? "panel" : "island") };
        runs = r;
        current = id;
        if (r[id].where === "panel") Ai.messages = Ai.messages.concat([{ role: "user", text: goal, shown: goal, local: true }, { role: "assistant", kind: "agent", text: "", runId: id }]);
        else { Halo.heard = goal; Halo.live({ duration: 120000 }); }
        history = [{ role: "user", text: "Goal: " + goal }];
        calls = []; blocked = 0; misses = 0; dry = 0;
        think();
    }
    function stop() {
        if (brain.running) brain.running = false;
        if (waitTimer.running) waitTimer.stop();
        pending = null;
        if (running) update(r => { r.state = "stopped"; r.steps = r.steps.map(s => s.state === "running" || s.state === "waiting" ? Object.assign({}, s, { state: "skipped" }) : s); });
    }

    // ── the model ──
    readonly property string toolGuide: tools.map(t => "- " + t.name + " " + t.args + ": " + t.desc).join("\n")
    function prompt() {
        const now = new Date();
        return "You are " + Halo.name + "'s planner inside Lumen, the user's Linux desktop (Fedora, Hyprland). You reach the user's goal by using tools, one at a time.\n"
            + "Reply with ONE JSON object and nothing else:\n"
            + "  {\"say\": \"<5-10 words: what you're doing>\", \"tool\": \"<name>\", \"args\": {…}}\n"
            + "or, when the goal is done (or needs no tools):\n"
            + "  {\"answer\": \"<short reply to the user, Markdown>\"}\n"
            + "Rules: do ONLY what the goal asks — no extra steps, no reminders or notes nobody asked for; one tool per reply; use the results you get and never invent facts; "
            + "never repeat a step that already worked; at most 6 tools; as soon as every part of the goal is done, reply with the answer; "
            + "clicks, typing, keys and shell commands ask the user first — just call them; if a tool fails, try one other way, then explain in the answer.\n"
            + "Tools:\n" + toolGuide + "\n"
            + "Example — goal \"start a 50 minute study timer and tell me my next class\":\n"
            + "{\"say\": \"Starting a 50-minute timer\", \"tool\": \"do\", \"args\": {\"command\": \"timer 50 min\"}}\n"
            + "(result) {\"say\": \"Checking your next class\", \"tool\": \"college\", \"args\": {\"question\": \"next class\"}}\n"
            + "(result) {\"answer\": \"Your 50-minute timer is running. Next class: Database Systems at 2:00 PM in SJT 418.\"}\n"
            + "Now: " + Qt.formatDateTime(now, "dddd d MMMM yyyy, h:mm AP") + ". The user: " + (Halo.you || "unknown") + ". "
            + "Focused window: " + (Hyprland.activeToplevel?.title || "none") + ". " + Halo.style;
    }
    function think() {
        if (!current || active?.state !== "running") return;
        if ((active?.steps ?? []).length >= maxSteps) { finish("I stopped after " + maxSteps + " steps — here's where I got to: " + summary()); return; }
        if (!Ai.configured) { finish("I need a model to plan with — choose one in Settings → Halo."); return; }
        const req = { provider: Ai.provider, model: Ai.model, system: prompt(), json: true,
                      messages: history.map(m => ({ role: m.role, text: m.text })) };
        reqFile.setText(JSON.stringify(req));
        brain.buf = "";
        brain.command = [Theme.lumenRoot + "/scripts/ai.sh", "ask", reqFile.path];
        brain.running = true;
    }
    FileView { id: reqFile; path: Ai.runDir + "/agent.json"; blockWrites: true; printErrors: false }
    Process {
        id: brain
        property string buf: ""
        property string err: ""
        stdout: SplitParser {
            onRead: line => {
                let d; try { d = JSON.parse(line); } catch (e) { return; }
                if (d.t) brain.buf += d.t;
                else if (d.e) brain.err = d.e;
            }
        }
        onExited: {
            if (!root.current || root.active?.state !== "running") return;
            if (brain.err && !brain.buf) { root.finish("I couldn't reach the model: " + brain.err); brain.err = ""; return; }
            root.decide(brain.buf);
        }
    }
    // The model's reply: a tool call, or the answer
    function parse(text) {
        const s = text.indexOf("{"), e = text.lastIndexOf("}");
        if (s < 0 || e <= s) return null;
        try { return JSON.parse(text.slice(s, e + 1)); } catch (x) {}
        // a trailing comma or a stray quote: one more try on the first object
        try { return JSON.parse(text.slice(s, text.indexOf("}", s) + 1)); } catch (x) {}
        return null;
    }
    property int misses: 0
    function decide(text) {
        const d = parse(text);
        if (!d || (!d.tool && d.answer === undefined)) {
            if (++misses <= 1) {
                history = history.concat([{ role: "assistant", text: text.slice(0, 400) }, { role: "user", text: "Reply with ONE JSON object only: a tool call or {\"answer\": …}." }]);
                think();
            } else finish(text.trim() || "I couldn't work out the next step.");
            return;
        }
        misses = 0;
        if (d.answer !== undefined && !d.tool) { finish(String(d.answer)); return; }
        const tool = tools.find(t => t.name === d.tool);
        const args = (typeof d.args === "object" && d.args) ? d.args : {};
        history = history.concat([{ role: "assistant", text: JSON.stringify({ say: d.say ?? "", tool: d.tool, args }) }]);
        if (!tool) { observe("Unknown tool \"" + d.tool + "\". Use one from the list."); return; }
        // Guards for small models: nothing the goal didn't ask for, no going round in circles
        const goal = (active?.goal ?? "").toLowerCase();
        if (tool.needs && !(typeof tool.needs === "function" ? tool.needs(args, goal) : tool.needs.test(goal))) {
            history = history.concat([{ role: "user", text: "Not allowed: the goal didn't ask for \"" + tool.name + "\". Don't do things nobody asked for. Reply with {\"answer\": …} now if you can." }]);
            if (++blocked >= 2) finish(fallbackAnswer()); else think();
            return;
        }
        const sig = tool.name + JSON.stringify(args);
        if (calls.includes(sig)) {
            history = history.concat([{ role: "user", text: "You already did exactly that. Use what you found and reply with {\"answer\": …} now." }]);
            if (++blocked >= 2) finish(fallbackAnswer()); else think();
            return;
        }
        calls = calls.concat([sig]);
        const say = (d.say && String(d.say).length < 90) ? String(d.say) : tool.label(args);
        update(r => r.steps.push({ tool: tool.name, say, icon: tool.icon, state: "running", result: "" }));
        if (tool.ask && tool.ask(args)) { pending = { tool, args }; update(r => { r.state = "waiting"; r.steps[r.steps.length - 1].state = "waiting"; }); return; }
        exec(tool, args);
    }
    property var calls: []              // tool+args already used this run
    property int blocked: 0
    property int dry: 0                 // results in a row that found nothing
    // When the model can't land it: say plainly what happened
    function fallbackAnswer() {
        const steps = (active?.steps ?? []);
        const found = steps.filter(s => s.state === "done" && s.result).map(s => "- " + s.say + ": " + s.result);
        return (found.length ? "Here's what I found:\n" + found.join("\n") : "I couldn't do that.") + "\n\n(I stopped there rather than guess.)";
    }
    property var pending: null
    function approve(yes) {
        if (!pending) return;
        const p = pending; pending = null;
        update(r => { r.state = "running"; });
        if (yes) { update(r => { r.steps[r.steps.length - 1].state = "running"; }); exec(p.tool, p.args); }
        else observe("The user said no to that step.", "skipped");
    }
    function exec(tool, args) {
        try { tool.run(args, (res, ok) => root.observe(res, ok === false ? "failed" : "done")); }
        catch (e) { observe("That tool failed: " + e, "failed"); }
    }
    function observe(result, state) {
        if (!current || (active?.state !== "running" && active?.state !== "waiting")) return;
        const short = String(result ?? "").slice(0, 2500);
        const empty = state === "failed" || /^(no |nothing |couldn't|didn't happen)/i.test(short);
        dry = empty ? dry + 1 : 0;
        if (dry >= 3) {
            update(r => { const s = r.steps[r.steps.length - 1]; if (s) { s.state = state ?? "done"; s.result = short.split("\n")[0].slice(0, 140); } });
            finish(fallbackAnswer());
            return;
        }
        update(r => { const s = r.steps[r.steps.length - 1]; if (s) { s.state = state ?? "done"; s.result = short.split("\n")[0].slice(0, 140); } });
        // keep small models on track: what's done, and the way out
        const done = (active?.steps ?? []).filter(s => s.state === "done").map(s => s.say);
        history = history.concat([{ role: "user", text: "Result: " + short + "\n\nGoal: " + (active?.goal ?? "") + "\nDone so far: " + (done.join("; ") || "nothing")
                                                         + "\nIf every part of the goal is done, reply now with {\"answer\": …} using these results. Otherwise call the next tool." }]);
        think();
    }
    function summary() { return (active?.steps ?? []).map(s => s.say + (s.state === "done" ? " ✓" : " (" + s.state + ")")).join("; "); }
    function finish(answer) {
        update(r => { r.answer = answer; r.state = "done"; });
        const r = active;
        if (r?.where === "island")
            Halo.say({ key: "live", icon: "auto_awesome", title: "“" + r.goal + "”", text: Voice.speakable(answer) || answer, level: "asked", tone: "happy", duration: 14000,
                       actions: [{ label: "Open in Halo", icon: "open_in_full", run: () => { Ai.show(); Ai.note({ icon: "auto_awesome", title: r.goal, text: answer }); } }],
                       speak: answer });
        else { Halo.react("happy", 1600); Voice.say(answer); }
    }
    // A step that needs the real screen: the panel steps aside and the run continues in the island
    function needScreen(then) {
        if (Ai.open) { update(r => { r.where = "island"; }); Halo.heard = active?.goal ?? ""; }
        Hands.clearView(then);
    }

    // ── tools ──
    function capture(fn) {
        let said = null;
        Halo.capture = c => said = c;
        try { fn(); } finally { Halo.capture = null; }
        return said;
    }
    Component {
        id: runner
        Process {
            id: rp
            property var cb: null
            stdout: StdioCollector { onStreamFinished: { const f = rp.cb; rp.cb = null; if (f) f(text); rp.destroy(); } }
        }
    }
    Timer { id: waitTimer; property var cb: null; onTriggered: { const f = cb; cb = null; if (f) f("Waited."); } }
    Connections {
        target: Hands
        function onOutcome(ok, why) { if (root.handsCb) { const f = root.handsCb; root.handsCb = null; f(ok ? "Done." + (why ? " " + why : "") : "Didn't happen: " + why, ok); } }
    }
    property var handsCb: null

    readonly property var tools: [
        { name: "do", needs: (a, goal) => {
              // the command must be about something the goal mentions
              const stop = ["the", "a", "an", "to", "on", "off", "my", "me", "and", "it", "set", "turn", "start", "open", "go", "for", "of", "in", "please"];
              const words = String(a.command ?? "").toLowerCase().split(/[^a-z0-9]+/).filter(w => w.length > 1 && !stop.includes(w));
              return words.some(w => goal.includes(w) || goal.includes(w.replace(/s$/, "")));
          }, args: "{\"command\": \"…\"}", icon: "bolt",
          desc: "anything Lumen does directly: settings (\"dark mode on\", \"volume 40\", \"night light on\", \"wifi off\", \"do not disturb on\"), apps (\"open firefox\"), windows (\"switch to firefox\", \"go to workspace 2\", \"maximise\"), timers (\"timer 25 min\"), focus (\"focus study\"), music (\"pause\", \"next song\"), \"stay awake 1 hour\"",
          label: a => a.command ?? "Doing it",
          ask: a => !!Halo.intent(a.command ?? "")?.ask,
          run: (a, done) => {
              const cmd = String(a.command ?? "");
              if (/^(click|press|type|point|scroll|where)\b/i.test(cmd)) { done("Use the click / type / key / point / scroll tools for that.", false); return; }
              const it = Halo.intent(cmd);
              if (!it) { done("Lumen has no direct action for \"" + cmd + "\".", false); return; }
              if (it.own) { const c = root.capture(it.own); done(c ? [c.title, c.text].filter(x => x).join(" — ") : "Started: " + it.title); return; }
              if (it.already) { done(it.title); return; }
              it.run();
              done("Done: " + (it.doneTitle ?? it.title));
          } },
        { name: "college", needs: /class|lecture|lab|attendance|bunk|skip|mark|grade|fat\b|cat\b|exam|timetable|semester|college|course|subject|vit|revision|study/, args: "{\"question\": \"…\"}", icon: "school",
          desc: "the user's VIT college data (AmazeCC): \"next class\", \"classes tomorrow\", \"attendance\", \"attendance in OS\", \"can I skip friday\", \"marks in DBMS\", \"what do I need in the FAT for an A in OS\", \"exams\"",
          label: a => "Checking: " + (a.question ?? "college"),
          run: (a, done) => done(HaloCollege.text(String(a.question ?? ""))) },
        { name: "remind", needs: /remind|alarm|don't let me forget|ping me/, args: "{\"when\": \"in 20 min | 9pm | tomorrow 8am\", \"text\": \"…\"}", icon: "alarm",
          desc: "a reminder at a time", label: a => "Reminder: " + (a.text ?? ""),
          run: (a, done) => { const at = Halo.whenFrom(String(a.when ?? "")); if (at <= Date.now()) { done("Couldn't read the time \"" + a.when + "\".", false); return; }
                              Halo.addReminder(at, String(a.text ?? "Reminder")); done("Reminder set " + Halo.whenText(at) + "."); } },
        { name: "todo", needs: /to-?do|task|checklist|plan|list/, args: "{\"text\": \"…\"}", icon: "checklist", desc: "add a to-do to the planner", label: a => "To-do: " + (a.text ?? ""),
          run: (a, done) => { Planner.addTodo(String(a.text ?? "")); done("Added to the to-dos."); } },
        { name: "event", needs: /event|calendar|schedule|plan|add|book/, args: "{\"text\": \"title and time, e.g. Lab record 5pm friday\"}", icon: "event", desc: "add an event to the planner's calendar", label: a => "Event: " + (a.text ?? ""),
          run: (a, done) => done(Planner.addEvent(String(a.text ?? "")) ? "Added to the calendar." : "Couldn't read a time from that — include one like \"5pm friday\".", true) },
        { name: "note_new", needs: /note|write|save|plan|jot|document/, args: "{\"title\": \"…\", \"text\": \"…\"}", icon: "note_add", desc: "create a note in the user's Notes", label: a => "New note: " + (a.title ?? ""),
          run: (a, done) => {
              const py = Theme.lumenRoot + "/scripts/notes.py";
              const p = runner.createObject(root, { cb: out => { Notes.refresh(); done(out.trim() ? "Created the note \"" + a.title + "\"." : "Couldn't create the note.", !!out.trim()); } });
              p.command = ["sh", "-c", 'f=$("$1" --dir "$2" new "$3") && "$1" --dir "$2" append "$f" "$4" >/dev/null && echo "$f"', "sh", py, Notes.dir, String(a.title ?? "Note"), String(a.text ?? "")];
              p.running = true;
          } },
        { name: "notes_find", args: "{\"query\": \"…\"}", icon: "search", desc: "find the user's notes by title or content", label: a => "Looking in notes: " + (a.query ?? ""),
          run: (a, done) => {
              const words = String(a.query ?? "").toLowerCase().split(/\s+/).filter(w => w.length > 1);
              const hits = Notes.all.map(n => ({ n, s: words.filter(w => (n.title + " " + (n.preview ?? "")).toLowerCase().includes(w)).length })).filter(x => x.s > 0).sort((x, y) => y.s - x.s).slice(0, 6);
              done(hits.length ? hits.map(x => "- " + x.n.title + (x.n.preview ? ": " + x.n.preview.slice(0, 80) : "")).join("\n") : "No notes match.");
          } },
        { name: "note_read", args: "{\"title\": \"…\"}", icon: "description", desc: "read one note", label: a => "Reading: " + (a.title ?? ""),
          run: (a, done) => {
              const q = String(a.title ?? "").toLowerCase();
              const n = Notes.all.find(x => x.title.toLowerCase() === q) ?? Notes.all.find(x => x.title.toLowerCase().includes(q));
              if (!n) { done("No note called \"" + a.title + "\".", false); return; }
              const p = runner.createObject(root, { cb: out => done(out.slice(0, 5000) || "(empty)") });
              p.command = ["head", "-c", "5000", Notes.pathOf(n.file)]; p.running = true;
          } },
        { name: "files_find", args: "{\"name\": \"…\"}", icon: "folder_open", desc: "find files in the user's home folder by name", label: a => "Finding files: " + (a.name ?? ""),
          run: (a, done) => {
              const pat = String(a.name ?? "").trim().split(/\s+/).map(w => w.replace(/[.*+?^${}()|[\]\\]/g, "\\$&")).join(".*");
              const p = runner.createObject(root, { cb: out => done(out.trim() || "No files found.") });
              p.command = ["sh", "-c", 'cd "$HOME" && fd -i -t f --max-results 12 --exclude ".*" -- "$1" 2>/dev/null | sed "s|^|$HOME/|"', "sh", pat]; p.running = true;
          } },
        { name: "file_read", args: "{\"path\": \"/home/…\"}", icon: "description", desc: "read a file (documents, PDFs, code)", label: a => "Reading " + String(a.path ?? "").replace(/.*\//, ""),
          run: (a, done) => {
              const p = runner.createObject(root, { cb: out => done(out.replace(/^@@IMAGE@@.*\n?/m, "").slice(0, 6000) || "(nothing readable)") });
              p.command = ["env", "HALO_LIMIT=6000", Theme.lumenRoot + "/scripts/halo-context.sh", "file", String(a.path ?? "")]; p.running = true;
          } },
        { name: "open", needs: /open|show|launch|view|play|watch|read/, args: "{\"target\": \"a file path or a URL\"}", icon: "open_in_new", desc: "open a file or web page", label: a => "Opening " + String(a.target ?? "").replace(/.*\//, ""),
          run: (a, done) => { const t = String(a.target ?? ""); if (!t) { done("Nothing to open.", false); return; }
                              Qt.openUrlExternally(t.startsWith("/") ? "file://" + t : t); done("Opened."); } },
        { name: "web", needs: /web|online|internet|google|browser|look (it )?up|search for|search the/, args: "{\"query\": \"…\"}", icon: "travel_explore", desc: "open a web search in the browser", label: a => "Searching the web: " + (a.query ?? ""),
          run: (a, done) => { Qt.openUrlExternally(Search.webSearchUrl.replace("%s", encodeURIComponent(String(a.query ?? "")))); done("Opened the search in the browser."); } },
        { name: "screen", args: "{}", icon: "visibility", desc: "the text on the user's screen right now", label: a => "Reading the screen",
          run: (a, done) => root.needScreen(() => { const p = runner.createObject(root, { cb: out => done(out.trim().slice(0, 5000) || "No readable text on screen.") });
                                                    p.command = [Theme.lumenRoot + "/scripts/halo-hands.py", "read"]; p.running = true; }) },
        { name: "windows", args: "{}", icon: "select_window", desc: "the open windows (app, title, workspace)", label: a => "Looking at your windows",
          run: (a, done) => done(Hyprland.toplevels.values.map(t => "- " + (t.lastIpcObject?.class ?? "") + ": " + (t.title ?? "") + " (workspace " + (t.workspace?.id ?? "?") + ")").join("\n") || "No windows.") },
        { name: "point", args: "{\"text\": \"text on screen, or a window\"}", icon: "near_me", desc: "move the pointer to something and mark it", label: a => "Pointing at " + (a.text ?? ""),
          run: (a, done) => root.needScreen(() => { root.handsCb = done; Hands.pointAt(String(a.text ?? "")); }) },
        { name: "click", needs: /click|press|tap|select|open|choose|hit|button|link/, args: "{\"text\": \"the button or link text\", \"button\": \"left|right|double\"}", icon: "ads_click", desc: "click something on screen (the user approves next to it)", label: a => "Clicking " + (a.text ?? ""),
          run: (a, done) => root.needScreen(() => { root.handsCb = done; Hands.clickText(String(a.text ?? ""), a.button ?? "left"); }) },
        { name: "type", needs: /type|write|fill|enter|search|reply/, args: "{\"text\": \"…\"}", icon: "keyboard", desc: "type into the focused window (the user approves)", label: a => "Typing",
          run: (a, done) => root.needScreen(() => { root.handsCb = done; Hands.type(String(a.text ?? "")); }) },
        { name: "key", needs: /press|key|shortcut|save|undo|copy|paste|close tab|new tab|ctrl|alt/, args: "{\"combo\": \"ctrl+s\"}", icon: "keyboard", desc: "press keys in the focused window (the user approves)", label: a => "Pressing " + (a.combo ?? ""),
          run: (a, done) => root.needScreen(() => { root.handsCb = done; Hands.key(String(a.combo ?? "")); }) },
        { name: "scroll", args: "{\"direction\": \"up|down\"}", icon: "swap_vert", desc: "scroll where the pointer is", label: a => "Scrolling " + (a.direction ?? "down"),
          run: (a, done) => root.needScreen(() => { root.handsCb = done; Hands.scroll(a.direction === "up" ? "up" : "down", 6); }) },
        { name: "wait", args: "{\"seconds\": 2}", icon: "hourglass_top", desc: "wait for an app to open before looking at the screen", label: a => "Waiting a moment",
          run: (a, done) => { waitTimer.interval = Math.max(500, Math.min(6000, Number(a.seconds ?? 2) * 1000)); waitTimer.cb = done; waitTimer.restart(); } },
        { name: "whatsapp", needs: /whatsapp|message|text|tell|send|let .* know/, args: "{\"to\": \"name\", \"text\": \"…\"}", icon: "chat", desc: "prepare a WhatsApp message (the user presses Send)", label: a => "Drafting a message to " + (a.to ?? ""),
          run: (a, done) => { if (!WhatsApp.enabled) { done("WhatsApp isn't set up in Lumen.", false); return; }
                              const ok = Ai.whatsappDraft("/wa " + a.to + ": " + a.text); done(ok ? "Draft ready — the user sends it." : "Couldn't prepare it.", ok); } },
        { name: "status", args: "{}", icon: "monitor_heart", desc: "this computer now: battery, memory, CPU, temperature, disk, busiest apps", label: a => "Checking the computer",
          run: (a, done) => { const d = Doctor.last;
                              const bat = Battery.available ? Math.round(Battery.percentage * 100) + "% battery" + (Battery.pluggedIn ? " (charging)" : Battery.forecastText ? ", about " + Battery.forecastText + " left" : "") : "";
                              if (!d) { done(bat || "No reading yet."); return; }
                              done([bat, Math.round(100 * d.mem.available / d.mem.total) + "% memory free", d.temp ? Math.round(d.temp) + " °C" : "",
                                    "busiest: " + (d.apps ?? []).slice(0, 3).map(g => g.name + " " + Math.round(100 * g.cores / d.ncpu) + "% CPU, " + Doctor.bytes(g.mem)).join("; "),
                                    (d.fs ?? []).map(f => f.mount + " " + Doctor.bytes(f.free) + " free").join(", ")].filter(x => x).join("\n")); } },
        { name: "weather", args: "{}", icon: "partly_cloudy_day", desc: "the weather now and the next days", label: a => "Checking the weather",
          run: (a, done) => done(!Weather.ready ? "No weather (no place set in Lumen)." : Math.round(Weather.now.temp) + "°, " + Weather.describe(Weather.now.code) + "\n"
                                 + (Weather.days ?? []).slice(0, 4).map(d => d.date + ": " + Math.round(d.min) + "–" + Math.round(d.max) + "°, " + Weather.describe(d.code)).join("\n")) },
        { name: "calendar", args: "{}", icon: "event_note", desc: "upcoming events, exams and holidays", label: a => "Checking the calendar",
          run: (a, done) => done((Planner.upcoming ?? []).slice(0, 10).map(e => "- " + e.title + ": " + Planner.whenLabel(e.when, e.allDay)).join("\n") || "Nothing coming up.") },
        { name: "notifications", args: "{}", icon: "notifications", desc: "notifications from the last few hours", label: a => "Reading notifications",
          run: (a, done) => { const s = Brief.since(Date.now() - 6 * 3600000); done(s.texts.slice(-25).join("\n") || "No notifications."); } },
        { name: "shell", needs: /command|terminal|run|install|update|shell|script/, args: "{\"command\": \"…\"}", icon: "terminal", desc: "run a shell command in a visible terminal (the user approves; you won't see the output)", label: a => "Run: " + (a.command ?? ""),
          ask: a => true,
          run: (a, done) => { Ai.run(String(a.command ?? "")); done("Opened in a terminal."); } },
    ]

    IpcHandler {
        target: "agent"
        function run(goal: string): void { root.start(goal, Ai.open ? "panel" : "island"); }
        function stop(): void { root.stop(); }
        function approve(): void { root.approve(true); }
        function deny(): void { root.approve(false); }
        function state(): string { return JSON.stringify(root.active); }
    }
}
