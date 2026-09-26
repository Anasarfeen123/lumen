pragma Singleton
// Lumen Halo — the assistant built into the desktop (Super+Shift+Space).
// Ask about what you selected, what's on screen, your system or your project.
// Off until you choose a provider in Settings → Halo:
//   ollama     local models, nothing leaves the machine
//   anthropic  Claude via your own API key (stored 600, outside the repo)
// Conversations live in memory only. scripts/ai.sh does all model I/O;
// scripts/halo-context.sh reads context, only for the chips you turn on.
//
// Skills are slash commands (/explain, /cmd, /diagnose …): a prompt template
// plus the context it needs. Typing "/" in the panel lists them.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root
    property bool open: false
    function toggle() { if (open) open = false; else show(); }
    function show() {
        open = true;
        readSelection();
        refreshStatus();
        if (Context.kind === "dev") Context.refreshDev();
        warm();
    }

    property string devProvider: ""          // LUMEN_DEV only: "mock"
    readonly property string provider: devProvider || (Persist.data.aiProvider ?? "off")
    readonly property var defaults: ({ anthropic: "claude-sonnet-5", ollama: status.ollamaModels?.[0] ?? "gemma3:4b", mock: "demo" })
    // Local models: "auto" (the default) answers with the smallest text model
    // you have — it fits in video memory, so it's fast — and switches to a
    // model that reads images only when a screenshot is attached.
    readonly property bool auto: provider === "ollama" && (Persist.data.aiModel === "auto" || !Persist.data.aiModel)
    readonly property var localInfo: (status.ollamaInfo ?? []).slice().sort((a, b) => a.size - b.size)
    readonly property string textModel: (localInfo.find(i => !i.vision) ?? localInfo[0])?.name ?? "gemma3:4b"
    readonly property string visionModel: localInfo.find(i => i.vision)?.name ?? ""
    readonly property string model: {
        if (auto) return textModel;
        const m = Persist.data.aiModel === "auto" ? "" : Persist.data.aiModel;
        if (provider === "ollama" && m && !(status.ollamaModels ?? []).includes(m) && (status.ollamaModels ?? []).length) return textModel;
        return (m || defaults[provider]) ?? "";
    }
    function modelFor(withImage) { return withImage && auto && visionModel ? visionModel : model; }
    readonly property bool local: provider === "ollama" || provider === "mock"
    readonly property bool configured: provider === "mock" ? true
                                     : provider === "anthropic" ? status.anthropic
                                     : provider === "ollama" ? (status.ollama && (status.ollamaModels ?? []).length > 0) : false
    // Can the current model read screenshots?
    readonly property bool vision: provider !== "ollama" || (auto ? visionModel !== "" : ((status.ollamaInfo ?? []).find(i => i.name === model)?.vision ?? false))
    readonly property bool modelLoaded: provider !== "ollama" || (status.loaded ?? []).includes(model)

    property var status: ({ anthropic: false, ollama: false, ollamaModels: [], ollamaInfo: [], loaded: [] })
    function refreshStatus() { statusProc.running = true; }
    Process {
        id: statusProc
        command: [Theme.lumenRoot + "/scripts/ai.sh", "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.status = JSON.parse(text); } catch (e) {} } }
    }
    function setModel(provider, model) {
        Persist.data.aiProvider = provider;
        Persist.data.aiModel = model;
        Qt.callLater(warm);
    }
    // Local models: load in the background when Halo opens, so the first
    // answer starts at once (Ollama keeps it for 15 minutes)
    function warm() {
        if (provider !== "ollama" || !configured || modelLoaded) return;
        Quickshell.execDetached([Theme.lumenRoot + "/scripts/ai.sh", "warm", model]);
        warmCheck.restart();
    }
    Timer { id: warmCheck; interval: 6000; onTriggered: root.refreshStatus() }

    // ── skills ──
    // prompt: what's sent (arg = text after the command); ctx: chips turned on
    readonly property var skills: [
        { id: "explain",   icon: "lightbulb",        label: "Explain",       hint: "Explain the selection or anything",       prompt: a => a ? "Explain this clearly: " + a : "Explain this clearly." },
        { id: "summarize", icon: "short_text",       label: "Summarize",     hint: "Key points in a few bullets",             prompt: a => "Summarize this in a few bullet points." + (a ? " Focus on: " + a : "") },
        { id: "fix",       icon: "spellcheck",       label: "Fix writing",   hint: "Grammar and flow; replies with the text", prompt: a => "Fix the grammar and make this read naturally" + (a ? " (" + a + ")" : "") + ". Reply with only the corrected text, no preamble." },
        { id: "rewrite",   icon: "edit_note",        label: "Rewrite",       hint: "/rewrite formal · casual · shorter",      prompt: a => "Rewrite this to be " + (a || "clearer and more concise") + ". Reply with only the rewritten text." },
        { id: "translate", icon: "translate",        label: "Translate",     hint: "/translate <language>",                   prompt: a => "Translate this into " + (a || "English") + ". Reply with only the translation." },
        { id: "reply",     icon: "reply",            label: "Draft a reply", hint: "Reply to the selected message",           prompt: a => "Draft a reply to this message" + (a ? " that says: " + a : "") + ". Keep the sender's tone. Reply with only the draft." },
        { id: "cmd",       icon: "terminal",         label: "Command",       hint: "/cmd <what you want to do>",              prompt: a => "Give me a single shell command for Fedora Linux (bash) that does this: " + a + "\nReply with the command in one ```sh code block, then one short line explaining it. If it's destructive, say so first." },
        { id: "diagnose",  icon: "stethoscope",      label: "Diagnose",      hint: "Check this computer for problems",        ctx: ["system"],  prompt: a => (a ? "Problem: " + a + "\n" : "") + "Look at this system snapshot and tell me what's wrong or worth attention, most important first, with the exact fix for each. If all is well, say so briefly." },
        { id: "screen",    icon: "visibility",       label: "Screen",        hint: "What's on my screen?",                    screen: true,     prompt: a => a || "What's on my screen? Point out anything important." },
        { id: "window",    icon: "select_window",    label: "This window",   hint: "Help with the app you're in",             ctx: ["window"], screen: true, prompt: a => a || "Help me with what I'm doing in this window. What should I know or do next?" },
        { id: "commit",    icon: "commit",           label: "Commit message", hint: "From your project's diff",              ctx: ["project"], prompt: a => "Write a git commit message for this diff: a short imperative subject (max 72 chars), a blank line, then a few bullet points on what changed and why." + (a ? " Context: " + a : "") + " Reply with only the message." },
        { id: "review",    icon: "rate_review",      label: "Review code",   hint: "Bugs and risks in your changes",          ctx: ["project"], prompt: a => "Review this diff for bugs, risky changes and missing edge cases. Be specific (file and line), most serious first." + (a ? " Focus: " + a : "") },
        { id: "clip",      icon: "content_paste",    label: "Clipboard",     hint: "Ask about what you copied",               ctx: ["clipboard"], prompt: a => a || "What is this, and what can I do with it?" },
        { id: "define",    icon: "menu_book",        label: "Define",        hint: "/define <word>",                          prompt: a => "Define \"" + a + "\" briefly: meaning, one example sentence, and synonyms." },
        { id: "eli5",      icon: "child_care",       label: "Simply",        hint: "Explain it like I'm new to this",         prompt: a => "Explain this simply, as to someone new to the topic, with an everyday analogy." + (a ? " " + a : "") },
    ]
    function skillFor(text) {
        const m = text.match(/^\/(\w+)\s*([\s\S]*)$/);
        if (!m) return null;
        const s = skills.find(x => x.id === m[1].toLowerCase());
        return s ? { skill: s, arg: m[2].trim() } : null;
    }
    function skillMatches(text) {
        const m = text.match(/^\/(\w*)$/);
        if (!m) return [];
        const q = m[1].toLowerCase();
        return skills.filter(s => s.id.startsWith(q) || s.label.toLowerCase().startsWith(q));
    }

    // ── context chips ──
    property string selection: ""
    property bool useSelection: true
    property bool useScreen: false
    property bool useClipboard: false
    property bool useWindow: false
    property bool useSystem: false
    property bool useProject: false
    readonly property string projectDir: Context.projectDir
    function readSelection() { selProc.running = true; }
    Process {
        id: selProc
        command: ["sh", "-c", "wl-paste --primary --no-newline 2>/dev/null | head -c 12000"]
        stdout: StdioCollector { onStreamFinished: { root.selection = text.trim(); root.useSelection = root.selection !== ""; } }
    }

    // ── conversation ──
    property var messages: []           // { role, text, image?, prompt?, chips? }
    property bool busy: false
    property string phase: ""           // "" | "reading" (context) | "looking" (screenshot) | "thinking"
    property string error: ""
    property real speed: 0              // tokens/s of the last local answer
    property var history: []            // what you typed, for ↑
    readonly property string runDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lumen-ai"
    readonly property string system: "You are Halo, the assistant built into Lumen, the user's Linux desktop (Fedora, Hyprland). "
        + "Be concise and practical; answer in Markdown. Use fenced code blocks with a language for commands and code. "
        + "When given selected text, a screenshot, a system snapshot or a diff, focus on it. "
        + "For commands, prefer Fedora (dnf) and say clearly before anything destructive."

    function clear() { stop(); messages = []; error = ""; speed = 0; }
    function stop() { if (ask.running) ask.running = false; ctxProc.running = false; busy = false; phase = ""; }

    // Build the prompt: skill → context blocks → screenshot → ask
    property var pending: null          // { text, chips, ctx: [kinds], ctxText, screen }
    function send(raw) {
        raw = raw.trim();
        if (!raw || busy) return;
        if (!configured) { error = provider === "off" ? "Choose where answers come from — Settings → Halo." : "Halo isn't ready yet — Settings → Halo."; return; }
        error = "";
        history = history.filter(h => h !== raw).concat([raw]).slice(-30);
        const sk = skillFor(raw);
        let prompt = sk ? sk.skill.prompt(sk.arg) : raw;
        const ctx = [];
        if (useClipboard) ctx.push("clipboard");
        if (useWindow) ctx.push("window");
        if (useSystem) ctx.push("system");
        if (useProject && projectDir) ctx.push("project");
        for (const c of (sk?.skill.ctx ?? [])) if (!ctx.includes(c) && (c !== "project" || projectDir)) ctx.push(c);
        if (sk?.skill.ctx?.includes("project") && !projectDir) { error = "Open a terminal or editor in your project first, then ask again."; return; }
        const screen = (useScreen || !!sk?.skill.screen) && vision;
        const chips = [];
        if (useSelection && selection && messages.length === 0) {
            prompt = "Selected text:\n```\n" + selection + "\n```\n\n" + prompt;
            chips.push("selection");
        }
        pending = { text: prompt, shown: raw, chips: chips.concat(ctx).concat(screen ? ["screen"] : []), ctx, ctxText: "", screen };
        busy = true;
        useScreen = false;
        nextContext();
    }
    function nextContext() {
        if (!busy) return;
        const p = pending;
        if (p.ctx.length > 0) {
            const kind = p.ctx.shift();
            phase = "reading";
            ctxProc.kind = kind;
            ctxProc.command = [Theme.lumenRoot + "/scripts/halo-context.sh", kind].concat(kind === "project" ? [projectDir] : []);
            ctxProc.running = true;
            return;
        }
        if (p.ctxText) p.text = p.ctxText + "\n\n" + p.text;
        if (p.screen) {
            phase = "looking";
            capture.file = runDir + "/screen-" + Date.now() + ".jpg";
            capture.command = ["sh", "-c", 'mkdir -p "$1" && chmod 700 "$1" && exec "$2" capture "$3"', "sh", runDir, Theme.lumenRoot + "/scripts/ai.sh", capture.file];
            capture.running = true;
        } else begin("");
    }
    Process {
        id: ctxProc
        property string kind: ""
        stdout: StdioCollector {
            onStreamFinished: {
                if (!root.pending) return;
                const label = ({ clipboard: "Clipboard", window: "Focused window", system: "System snapshot", project: "Project" })[ctxProc.kind];
                if (text.trim()) root.pending.ctxText += label + ":\n```\n" + text.trim() + "\n```\n\n";
                root.nextContext();
            }
        }
    }
    Process {
        id: capture
        property string file: ""
        onExited: code => root.begin(code === 0 ? capture.file : "")
    }
    function begin(image) {
        if (!busy) return;
        const user = { role: "user", text: pending.text, shown: pending.shown, chips: pending.chips };
        if (image) user.image = image;
        messages = messages.concat([user, { role: "assistant", text: "" }]);
        phase = "thinking";
        speed = 0;
        const req = { provider, model: modelFor(!!image), system,
                      messages: messages.slice(0, -1).map(m => Object.assign({ role: m.role, text: m.text }, m.image ? { image: m.image } : {})) };
        reqFile.setText(JSON.stringify(req));
        ask.command = [Theme.lumenRoot + "/scripts/ai.sh", "ask", reqFile.path];
        ask.running = true;
    }
    // Ask the last question again (a new answer)
    function retry() {
        if (busy) return;
        let i = messages.length - 1;
        while (i >= 0 && messages[i].role !== "user") i--;
        if (i < 0) return;
        const u = messages[i];
        messages = messages.slice(0, i);
        pending = { text: u.text, shown: u.shown, chips: u.chips ?? [], ctx: [], ctxText: "", screen: false };
        busy = true;
        begin(u.image ?? "");
    }
    FileView { id: reqFile; path: root.runDir + "/request.json"; blockWrites: true; printErrors: false }
    Process {
        id: ask
        stdout: SplitParser {
            onRead: line => {
                let d; try { d = JSON.parse(line); } catch (e) { return; }
                if (d.e) { root.error = d.e; return; }
                if (d.s) { root.speed = d.s.ms > 0 ? Math.round(d.s.n / (d.s.ms / 1000)) : 0; return; }
                if (d.t) {
                    const m = root.messages.slice();
                    const last = Object.assign({}, m[m.length - 1]);
                    last.text += d.t;
                    m[m.length - 1] = last;
                    root.messages = m;
                }
            }
        }
        onExited: {
            root.busy = false;
            root.phase = "";
            root.refreshStatus();
            // Drop an empty answer bubble if the request failed
            const m = root.messages;
            if (m.length && m[m.length - 1].role === "assistant" && m[m.length - 1].text === "") root.messages = m.slice(0, -1);
            else if (!root.open && m.length) root.announceDone();
        }
    }

    // Thinking in the background: the island shows it, then says when it's done
    readonly property bool islandBusy: busy && !open
    onIslandBusyChanged: if (islandBusy) Island.progress("halo", "auto_awesome", "Halo is thinking", -1, local ? "On this computer" : "Claude")
    function announceDone() {
        Island.push({ kind: "system", key: "progress:halo", priority: Island.priority.system, duration: 3500, queueable: true, force: true,
                      data: { icon: "auto_awesome", title: "Halo answered", detail: "Super+Shift+Space to read it", tone: "normal" } });
    }

    // ── what you can do with an answer ──
    function copy(text) { Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", text]); }
    // Into the app you came from: copy, close Halo, paste
    function insert(text) { copy(text); open = false; Clipboard.pasteSoon(); }
    function saveToNotes(text) {
        const stamp = Qt.formatDateTime(new Date(), "d MMM, hh:mm");
        Planner.setNotes((Planner.notes ? Planner.notes.replace(/\s*$/, "") + "\n\n" : "") + "— Halo, " + stamp + "\n" + text.trim() + "\n");
        Island.system("note_add", "Saved to notes", "Planner → Notes");
    }
    // A command from an answer, in a terminal that stays open. Never automatic:
    // the panel asks you to confirm first.
    function run(cmd) {
        open = false;
        Quickshell.execDetached(["kitty", "--title", "Halo · command", "--hold", "sh", "-c", 'printf "\\033[2m$ %s\\033[0m\\n" "$1"; eval "$1"', "sh", cmd]);
    }
    // Commands that deserve a second look before running
    function risky(cmd) { return /\b(rm\s+-[a-z]*[rf]|dd\s|mkfs|shred|wipefs|chmod\s+-R|chown\s+-R|>\s*\/dev\/sd|:\(\)\s*\{|sudo\s+rm|dnf\s+remove|kill\s+-9|systemctl\s+(stop|disable|mask))/i.test(cmd); }
    // ```lang\ncode``` blocks of an answer
    function codeBlocks(text) {
        const out = [], re = /```([\w+-]*)\n([\s\S]*?)```/g;
        let m;
        while ((m = re.exec(text)) !== null) out.push({ lang: m[1].toLowerCase(), code: m[2].replace(/\n$/, "") });
        return out;
    }
    function isShell(lang) { return ["", "sh", "bash", "shell", "console", "zsh", "fish"].includes(lang); }

    GlobalShortcut { appid: "lumen"; name: "ai"; description: "Lumen Halo"; onPressed: root.toggle() }
    IpcHandler {
        target: "ai"
        function toggle(): void { root.toggle(); }
        function ask(q: string): void { root.show(); root.send(q); }
    }
    IpcHandler {
        target: "aiTest"
        enabled: Quickshell.env("LUMEN_DEV") === "1"
        function mock(): void { root.devProvider = "mock"; }
        function real(): void { root.devProvider = ""; }
        function select(t: string): void { root.selection = t; root.useSelection = true; }
    }
}
