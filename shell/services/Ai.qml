pragma Singleton
// Lumen Halo — the assistant built into the desktop (Super+Shift+Space).
// Ask about what you selected, what's on screen, your system or your project.
// Off until you choose a provider in Settings → Halo:
//   ollama     local models, nothing leaves the machine
//   anthropic, openai, gemini, openrouter, groq, mistral
//              cloud models via your own API key (stored 600, outside the repo)
//   custom     any OpenAI-compatible server (LM Studio, llama.cpp, vLLM, Jan…)
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
    // Every provider Halo can use. key: the key's usual start (for the hint);
    // model: a sensible default until you pick one from the provider's list.
    readonly property var providers: [
        { id: "ollama",     label: "This computer", group: "local",  key: "",        model: "",                        site: "ollama.com",                   note: "Local models through Ollama. Nothing leaves this computer." },
        { id: "anthropic",  label: "Claude",        group: "cloud",  key: "sk-ant-", model: "claude-sonnet-5",         site: "console.anthropic.com",        note: "Anthropic's Claude." },
        { id: "openai",     label: "OpenAI",        group: "cloud",  key: "sk-",     model: "gpt-4o-mini",             site: "platform.openai.com",          note: "ChatGPT's models (GPT)." },
        { id: "gemini",     label: "Gemini",        group: "cloud",  key: "AIza",    model: "gemini-2.5-flash",        site: "aistudio.google.com",          note: "Google's Gemini (free tier available)." },
        { id: "openrouter", label: "OpenRouter",    group: "cloud",  key: "sk-or-",  model: "openrouter/auto",         site: "openrouter.ai",                note: "One key for hundreds of models from many companies." },
        { id: "groq",       label: "Groq",          group: "cloud",  key: "gsk_",    model: "llama-3.3-70b-versatile", site: "console.groq.com",             note: "Open models, answered very fast." },
        { id: "mistral",    label: "Mistral",       group: "cloud",  key: "",        model: "mistral-small-latest",    site: "console.mistral.ai",           note: "Mistral AI's models." },
        { id: "custom",     label: "Your server",   group: "custom", key: "",        model: "",                        site: "",                             note: "Any OpenAI-compatible server: LM Studio, llama.cpp, vLLM, LocalAI, Jan…" },
    ]
    function providerInfo(id) { return providers.find(p => p.id === id) ?? null; }
    readonly property var defaults: {
        const d = { ollama: status.ollamaModels?.[0] ?? "gemma3:4b", mock: "demo", mocklong: "demo", custom: status.custom?.model ?? "" };
        for (const p of providers) if (p.model) d[p.id] = p.model;
        return d;
    }
    // Is a provider ready to answer?
    function isConfigured(id) {
        if (id === "mock" || id === "mocklong") return true;
        if (id === "ollama") return status.ollama && (status.ollamaModels ?? []).length > 0;
        if (id === "custom") return !!status.custom?.url;
        return !!(status.keys ?? {})[id];
    }
    // Model lists, fetched from each provider when you look (never in the background)
    property var modelLists: ({})
    property var _fetching: ({})
    function fetchModels(id) {
        if (id === "ollama" || _fetching[id]) return;
        const f = Object.assign({}, _fetching); f[id] = true; _fetching = f;
        const proc = modelsComp.createObject(root, { pid: id });
        proc.running = true;
    }
    Component {
        id: modelsComp
        Process {
            id: mp
            property string pid: ""
            command: [Theme.lumenRoot + "/scripts/ai.sh", "models", pid]
            stdout: StdioCollector {
                onStreamFinished: {
                    let list = [];
                    try { list = JSON.parse(text); } catch (e) {}
                    // Only chat models are useful here
                    list = list.filter(m => !/embed|whisper|tts|dall-e|image|audio|moderation|rerank|transcri|realtime|search/i.test(m));
                    const l = Object.assign({}, root.modelLists); l[mp.pid] = list; root.modelLists = l;
                    const f = Object.assign({}, root._fetching); delete f[mp.pid]; root._fetching = f;
                    mp.destroy();
                }
            }
        }
    }
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
    readonly property bool local: provider === "ollama" || provider === "mock" || provider === "mocklong"
                                  || (provider === "custom" && /^https?:\/\/(127\.|localhost|\[::1\])/.test(status.custom?.url ?? ""))
    readonly property string providerLabel: provider === "ollama" ? "this computer" : (providerInfo(provider)?.label ?? provider)
    readonly property bool configured: isConfigured(provider)
    // Can the current model read screenshots? (Cloud: the big providers' main
    // models do; Groq and Mistral only some — guessed from the name.)
    readonly property bool vision: {
        if (provider === "ollama") return auto ? visionModel !== "" : ((status.ollamaInfo ?? []).find(i => i.name === model)?.vision ?? false);
        if (provider === "groq") return /vision|llama-4|scout|maverick/i.test(model);
        if (provider === "mistral") return /pixtral|medium|large|small-(2503|2506|latest)/i.test(model);
        return true;
    }
    readonly property bool modelLoaded: provider !== "ollama" || (status.loaded ?? []).includes(model)

    property var status: ({ anthropic: false, keys: {}, custom: {}, ollama: false, ollamaModels: [], ollamaInfo: [], loaded: [] })
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
        { id: "wa",        icon: "chat",             label: "WhatsApp",      hint: "/wa <name>: <message> — you confirm, WhatsApp sends", prompt: a => a },
        { id: "define",    icon: "menu_book",        label: "Define",        hint: "/define <word>",                          prompt: a => "Define \"" + a + "\" briefly: meaning, one example sentence, and synonyms." },
        { id: "pdf",       icon: "picture_as_pdf",   label: "Summarize a PDF", hint: "Pick a PDF (Downloads, Drop Zone)",    files: true, prompt: a => "Summarize this document: what it is, the key points as bullets, and anything I need to act on." + (a ? " Focus on: " + a : "") },
        { id: "file",      icon: "description",      label: "Ask about a file", hint: "/file <question> about files you pick", files: true, prompt: a => a || "What is in these files? Summarize each briefly and tell me anything important." },
        { id: "rename",    icon: "drive_file_rename_outline", label: "Rename files", hint: "Better names from what's inside",  files: true, rename: true,
          prompt: a => "Suggest clearer file names for these files, based on what's inside them." + (a ? " Style: " + a + "." : "")
                     + " Rules: keep each file's extension; at most 60 characters; readable words (e.g. \"Robotics Club Budget 2026-09.txt\"); include a date only if the content shows one; no slashes. "
                     + "Reply with ONLY a JSON array, no other text: [{\"from\": \"<current name>\", \"to\": \"<new name>\"}]" },
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

    // ── files (Downloads picker, Drop Zone, `ai files <path>`) ──
    property var files: []              // absolute paths, at most 5
    property bool pickerOpen: false
    property var downloads: []          // [{ path, name, size, mtime }] newest first
    function toggleFile(path) {
        if (files.includes(path)) files = files.filter(f => f !== path);
        else if (files.length < 5) files = files.concat([path]);
    }
    function clearFiles() { files = []; }
    function loadDownloads() { dlProc.running = true; }
    Process {
        id: dlProc
        command: [Theme.lumenRoot + "/scripts/halo-context.sh", "downloads"]
        stdout: StdioCollector {
            onStreamFinished: root.downloads = text.split("\n").filter(l => l).map(l => { try { return JSON.parse(l); } catch (e) { return null; } }).filter(x => x)
        }
    }
    // For the Drop Zone and scripts: open Halo with these files attached and,
    // if given, run a skill on them ("pdf", "file", "rename")
    function askAboutFiles(paths, skill) {
        files = paths.filter(p => typeof p === "string" && p.startsWith("/")).slice(0, 5);
        show();
        pickerOpen = false;
        if (skill) Qt.callLater(() => send("/" + skill));
    }

    // ── conversation ──
    property var messages: []           // { role, text, image?, prompt?, chips? }
    property bool busy: false
    property string phase: ""           // "" | "reading" (context) | "looking" (screenshot) | "thinking" | "writing"
    // The answer being written lives here, not in `messages`: replacing the
    // messages array on every token rebuilt every bubble and re-parsed all the
    // Markdown (a full CPU core while streaming). Tokens are batched every 90 ms;
    // the finished answer is stored in `messages` once.
    property string streamText: ""
    property string _pendingTokens: ""
    property real askStarted: 0         // when the question went to the model
    property bool slow: false           // no words after 15 s: say what's happening
    Timer {
        id: flush
        interval: 90
        onTriggered: { root.streamText += root._pendingTokens; root._pendingTokens = ""; }
    }
    Timer { id: slowTimer; interval: 15000; onTriggered: if (root.busy && root.streamText === "" && root._pendingTokens === "") root.slow = true }
    property string error: ""
    property real speed: 0              // tokens/s of the last local answer
    property var history: []            // what you typed, for ↑
    readonly property string runDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lumen-ai"
    readonly property string system: "You are Halo, the assistant built into Lumen, the user's Linux desktop (Fedora, Hyprland). "
        + "Be concise and practical; answer in Markdown. Use fenced code blocks with a language for commands and code. "
        + "When given selected text, a screenshot, a system snapshot or a diff, focus on it. "
        + "For commands, prefer Fedora (dnf) and say clearly before anything destructive."

    function clear() { stop(); messages = []; error = ""; speed = 0; }
    function stop() { if (ask.running) ask.running = false; ctxProc.running = false; busy = false; phase = ""; slow = false; }

    // ── WhatsApp (services/Inbox.qml) ──
    // "tell Arya I'll send the build tonight" · "/wa Arya: on my way"
    // Never sends: it becomes a card with Cancel / Send, and Send opens
    // WhatsApp with the text pre-filled so you press Enter there.
    function whatsappDraft(raw) {
        const m = raw.match(/^(?:\/wa\s+|(?:tell|message|text|whatsapp|wa)\s+)([\s\S]+)$/i);
        if (!m || !WhatsApp.enabled) return false;
        let rest = m[1].trim(), name = "", text = "";
        const colon = rest.match(/^([^:,]{1,40})[:,]\s*([\s\S]+)$/);
        if (colon) { name = colon[1]; text = colon[2]; }
        else {
            // The longest chat or contact name the sentence starts with, else the first word
            const known = Inbox.conversations.map(c => c.title).concat((WhatsApp.cfg.contacts ?? []).map(c => c.name))
                                .filter(n => n).sort((a, b) => b.length - a.length);
            name = known.find(n => rest.toLowerCase().startsWith(n.toLowerCase() + " ")) ?? rest.split(/\s+/)[0];
            text = rest.slice(name.length).trim().replace(/^(that|to say|saying)\s+/i, "");
        }
        if (!text) return false;
        const r = Inbox.draftFromHalo(name.trim(), text);
        error = "";
        messages = messages.concat([{ role: "user", text: raw, shown: raw },
                                    r.ok ? { role: "assistant", kind: "wa", text: "", draft: r.draft, needsNumber: r.needsNumber, state: "ask" }
                                         : { role: "assistant", text: "Couldn't prepare that WhatsApp message: " + (r.reason ?? "unknown chat") + "." }]);
        return true;
    }
    function waDecide(index, send) {
        const m = messages.slice(), msg = Object.assign({}, m[index]);
        if (msg.kind !== "wa" || msg.state !== "ask") return;
        msg.state = send ? "sent" : "cancelled";
        m[index] = msg;
        messages = m;
        if (send) { Inbox.send(msg.draft); open = false; }
    }
    // "what did Arya say …" → this session's WhatsApp previews as context (only if allowed)
    function whatsappContext(raw) {
        const m = raw.match(/what (?:did|has) ([\w .'-]+?) (?:say|said|send|sent|write)/i);
        if (m && WhatsApp.enabled) {
            const r = Inbox.recentFor(m[1]);
            if (r.ok) return "WhatsApp (" + r.source + ") — " + r.title + ":\n```\n" + r.messages.map(x => (x.sender ? x.sender + ": " : "") + x.text).join("\n") + "\n```\n\nSay that this comes from WhatsApp notifications seen this session.\n\n";
            return "(WhatsApp: " + r.reason + ". Tell the user this.)\n\n";
        }
        if (/whatsapp/i.test(raw) && /(catch ?up|while i was away|unread|missed)/i.test(raw) && WhatsApp.enabled) {
            const t = Inbox.unreadSummaryText();
            return t ? "Unread WhatsApp (notifications seen this session):\n" + t + "\n\n" : "(WhatsApp: Halo message context is off in Settings → WhatsApp. Tell the user.)\n\n";
        }
        return "";
    }

    // Build the prompt: skill → context blocks → screenshot → ask
    property var pending: null          // { text, chips, ctx: [kinds], ctxText, screen }
    function send(raw) {
        raw = raw.trim();
        if (!raw || busy) return;
        if (whatsappDraft(raw)) return;
        if (!configured) { error = provider === "off" ? "Choose where answers come from — Settings → Halo." : "Halo isn't ready yet — Settings → Halo."; return; }
        error = "";
        history = history.filter(h => h !== raw).concat([raw]).slice(-30);
        const sk = skillFor(raw);
        let prompt = whatsappContext(raw) + (sk ? sk.skill.prompt(sk.arg) : raw);
        const ctx = [];
        if (useClipboard) ctx.push("clipboard");
        if (useWindow) ctx.push("window");
        if (useSystem) ctx.push("system");
        if (useProject && projectDir) ctx.push("project");
        for (const c of (sk?.skill.ctx ?? [])) if (!ctx.includes(c) && (c !== "project" || projectDir)) ctx.push(c);
        if (sk?.skill.ctx?.includes("project") && !projectDir) { error = "Open a terminal or editor in your project first, then ask again."; return; }
        if (sk?.skill.files && files.length === 0) { pickerOpen = true; loadDownloads(); error = "Pick the files first (up to 5), then send again."; return; }
        // Attached files: one context read each (renaming needs only a taste of each)
        const attached = files.slice();
        for (const f of attached) ctx.push({ kind: "file", path: f, limit: sk?.skill.rename ? 1500 : 12000 });
        if (sk?.skill.rename)
            prompt = "Current names: " + attached.map(f => "\"" + f.replace(/.*\//, "") + "\"").join(", ") + "\n\n" + prompt;
        const screen = (useScreen || !!sk?.skill.screen) && vision;
        const chips = [];
        if (useSelection && selection && messages.length === 0) {
            prompt = "Selected text:\n```\n" + selection + "\n```\n\n" + prompt;
            chips.push("selection");
        }
        pending = { text: prompt, shown: raw, chips: chips.concat(ctx.map(c => typeof c === "string" ? c : "file")).concat(screen ? ["screen"] : []).filter((c, i, a) => a.indexOf(c) === i),
                    ctx, ctxText: "", screen, image: "", renameFor: sk?.skill.rename ? attached : null, fileNames: attached.map(f => f.replace(/.*\//, "")) };
        busy = true;
        useScreen = false;
        pickerOpen = false;
        files = [];
        nextContext();
    }
    function nextContext() {
        if (!busy) return;
        const p = pending;
        if (p.ctx.length > 0) {
            const c = p.ctx.shift();
            phase = "reading";
            if (typeof c === "string") {
                ctxProc.kind = c;
                ctxProc.command = [Theme.lumenRoot + "/scripts/halo-context.sh", c].concat(c === "project" ? [projectDir] : []);
            } else {
                ctxProc.kind = "file";
                ctxProc.command = ["env", "HALO_LIMIT=" + c.limit, Theme.lumenRoot + "/scripts/halo-context.sh", "file", c.path];
            }
            ctxProc.running = true;
            return;
        }
        if (p.ctxText) p.text = p.ctxText + "\n\n" + p.text;
        if (p.image) begin(p.image);
        else if (p.screen) {
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
                let body = text.trim();
                if (ctxProc.kind === "file") {
                    // An image comes back as a private JPEG to attach (vision models only)
                    const m = /^@@IMAGE@@ (.+)$/m.exec(body);
                    if (m) {
                        body = body.replace(/^@@IMAGE@@ .+\n?/m, "");
                        if (root.vision && !root.pending.image) root.pending.image = m[1];
                        else body += "\n(An image; " + (root.vision ? "only the first image is attached." : "the current model can't see images.") + ")";
                    }
                    if (body) root.pending.ctxText += body + "\n\n";
                } else {
                    const label = ({ clipboard: "Clipboard", window: "Focused window", system: "System snapshot", project: "Project" })[ctxProc.kind];
                    if (body) root.pending.ctxText += label + ":\n```\n" + body + "\n```\n\n";
                }
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
        const user = { role: "user", text: pending.text, shown: pending.shown, chips: pending.chips, fileNames: pending.fileNames ?? [], renameFor: pending.renameFor ?? null };
        if (image) user.image = image;
        messages = messages.concat([user, { role: "assistant", text: "" }]);
        phase = "thinking";
        speed = 0;
        streamText = ""; _pendingTokens = ""; slow = false;
        askStarted = Date.now();
        slowTimer.restart();
        const req = { provider, model: modelFor(!!image), system,
                      messages: messages.slice(0, -1).filter(m => m.kind !== "wa").map(m => Object.assign({ role: m.role, text: m.text }, m.image ? { image: m.image } : {})) };
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
        pending = { text: u.text, shown: u.shown, chips: u.chips ?? [], ctx: [], ctxText: "", screen: false, image: "", renameFor: u.renameFor ?? null, fileNames: u.fileNames ?? [] };
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
                    root._pendingTokens += d.t;
                    if (root.phase !== "writing") { root.phase = "writing"; root.slow = false; }
                    if (!flush.running) flush.start();
                }
            }
        }
        onExited: {
            flush.stop();
            const answer = root.streamText + root._pendingTokens;
            root.streamText = ""; root._pendingTokens = "";
            root.slow = false; slowTimer.stop();
            // Store the finished answer once
            if (answer !== "" && root.messages.length && root.messages[root.messages.length - 1].role === "assistant") {
                const mm = root.messages.slice();
                mm[mm.length - 1] = Object.assign({}, mm[mm.length - 1], { text: answer });
                root.messages = mm;
            }
            root.busy = false;
            root.phase = "";
            root.refreshStatus();
            // Drop an empty answer bubble if the request failed
            const m = root.messages;
            if (m.length && m[m.length - 1].role === "assistant" && m[m.length - 1].text === "") root.messages = m.slice(0, -1);
            else if (m.length >= 2 && m[m.length - 2].renameFor) root.parseRenames(m.length - 1);
            else if (!root.open && m.length) root.announceDone();
        }
    }

    // Thinking in the background: the island shows it, then says when it's done
    readonly property bool islandBusy: busy && !open
    onIslandBusyChanged: if (islandBusy) Island.progress("halo", "auto_awesome", "Halo is thinking", -1, local ? "On this computer" : providerLabel)
    function announceDone() {
        Island.push({ kind: "system", key: "progress:halo", priority: Island.priority.system, duration: 3500, queueable: true, force: true,
                      data: { icon: "auto_awesome", title: "Halo answered", detail: "Super+Shift+Space to read it", tone: "normal" } });
    }

    // ── /rename: a plan you check, apply, and can undo ──
    // Each answer to /rename gets msg.renames = [{ from: "/abs/path", to: "name", on: true }]
    function parseRenames(i) {
        const msg = messages[i], user = messages[i - 1];
        let list = null;
        const txt = msg.text;
        const block = /```(?:json)?\s*([\s\S]*?)```/.exec(txt);
        for (const cand of [block?.[1], txt, (/\[[\s\S]*\]/.exec(txt) ?? [])[0]]) {
            if (!cand) continue;
            try { const v = JSON.parse(cand.trim()); if (Array.isArray(v)) { list = v; break; } } catch (e) {}
        }
        if (!list) return;
        const byName = {};
        for (const f of user.renameFor) byName[f.replace(/.*\//, "")] = f;
        const renames = list.filter(r => r && typeof r.from === "string" && typeof r.to === "string" && byName[r.from.replace(/.*\//, "")])
                            .map(r => ({ from: byName[r.from.replace(/.*\//, "")], to: r.to.replace(/.*\//, "").trim(), on: r.to.trim() !== r.from.trim() }));
        if (!renames.length) return;
        const m = messages.slice();
        m[i] = Object.assign({}, msg, { renames, renameState: "plan" });
        messages = m;
    }
    function toggleRename(i, j) {
        const m = messages.slice(), r = m[i].renames.slice();
        r[j] = Object.assign({}, r[j], { on: !r[j].on });
        m[i] = Object.assign({}, m[i], { renames: r });
        messages = m;
    }
    function applyRenames(i) { renameRun("apply", i, JSON.stringify(messages[i].renames.filter(r => r.on).map(r => ({ from: r.from, to: r.to })))); }
    function undoRenames(i) { renameRun("undo", i, JSON.stringify(messages[i].renameResults ?? [])); }
    function renameRun(mode, i, plan) {
        renameProc.index = i;
        renameProc.mode = mode;
        planFile.setText(plan);
        renameProc.command = [Theme.lumenRoot + "/scripts/halo-rename.sh", mode, planFile.path];
        renameProc.running = true;
    }
    FileView { id: planFile; path: root.runDir + "/rename-plan.json"; blockWrites: true; printErrors: false }
    Process {
        id: renameProc
        property int index: -1
        property string mode: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const res = text.split("\n").filter(l => l).map(l => { try { return JSON.parse(l); } catch (e) { return null; } }).filter(x => x);
                const done = res.filter(r => r.status === "renamed").length, skipped = res.length - done;
                const m = root.messages.slice(), i = renameProc.index;
                if (!m[i]) return;
                m[i] = Object.assign({}, m[i], renameProc.mode === "apply" ? { renameResults: res, renameState: "applied" } : { renameState: "undone" });
                root.messages = m;
                Island.system(renameProc.mode === "apply" ? "drive_file_rename_outline" : "undo",
                              renameProc.mode === "apply" ? "Renamed " + done + (done === 1 ? " file" : " files") : "Put " + done + (done === 1 ? " name" : " names") + " back",
                              skipped ? skipped + " skipped — " + (res.find(r => r.status === "skipped")?.why ?? "") : "");
            }
        }
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
        // Attach a file (call again for more, up to 5); Halo opens with them
        function files(path: string): void { root.show(); if (path.startsWith("/") && !root.files.includes(path) && root.files.length < 5) root.files = root.files.concat([path]); }
    }
    IpcHandler {
        target: "aiTest"
        enabled: Quickshell.env("LUMEN_DEV") === "1"
        function mock(): void { root.devProvider = "mock"; }
        function mockLong(): void { root.devProvider = "mocklong"; }
        function busy(): bool { return root.busy; }
        function clear(): void { root.clear(); }
        function dump(): string { return JSON.stringify(root.messages.map(m => ({ role: m.role, text: m.text.slice(0, 400), renames: m.renames, state: m.renameState, results: m.renameResults }))); }
        function picker(): void { root.clear(); root.show(); root.pickerOpen = true; root.loadDownloads(); }
        function apply(): void { for (let i = root.messages.length - 1; i >= 0; i--) if (root.messages[i].renames) { root.applyRenames(i); return; } }
        function undo(): void { for (let i = root.messages.length - 1; i >= 0; i--) if (root.messages[i].renameResults) { root.undoRenames(i); return; } }
        function real(): void { root.devProvider = ""; }
        function select(t: string): void { root.selection = t; root.useSelection = true; }
    }
}
