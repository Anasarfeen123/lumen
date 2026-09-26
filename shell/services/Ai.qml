pragma Singleton
// Lumen AI: ask about what you selected, what's on screen, or anything.
// Off until you choose a provider in Settings → AI:
//   ollama     local models, nothing leaves the machine
//   anthropic  Claude via your own API key (stored 600, outside the repo)
// Conversations live in memory only. scripts/ai.sh does all network I/O.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root
    property bool open: false
    function toggle() { if (open) open = false; else show(); }
    function show() { open = true; readSelection(); refreshStatus(); }

    property string devProvider: ""          // LUMEN_DEV only: "mock"
    readonly property string provider: devProvider || (Persist.data.aiProvider ?? "off")
    readonly property var defaults: ({ anthropic: "claude-sonnet-5", ollama: status.ollamaModels?.[0] ?? "llama3.2", mock: "demo" })
    readonly property string model: (Persist.data.aiModel || defaults[provider]) ?? ""
    readonly property bool configured: provider === "mock" ? true
                                     : provider === "anthropic" ? status.anthropic
                                     : provider === "ollama" ? status.ollama : false
    property var status: ({ anthropic: false, ollama: false, ollamaModels: [] })
    function refreshStatus() { statusProc.running = true; }
    Process {
        id: statusProc
        command: [Theme.lumenRoot + "/scripts/ai.sh", "status"]
        stdout: StdioCollector { onStreamFinished: { try { root.status = JSON.parse(text); } catch (e) {} } }
    }

    // ── context ──
    property string selection: ""
    property bool useSelection: true
    property bool useScreen: false
    function readSelection() { selProc.running = true; }
    Process {
        id: selProc
        command: ["sh", "-c", "wl-paste --primary --no-newline 2>/dev/null | head -c 12000"]
        stdout: StdioCollector { onStreamFinished: { root.selection = text.trim(); root.useSelection = root.selection !== ""; } }
    }

    // ── conversation ──
    property var messages: []           // { role, text, image }
    property bool busy: false
    property string error: ""
    readonly property string runDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/lumen-ai"
    readonly property string system: "You are Lumen, the assistant built into the user's Linux desktop (Fedora, Hyprland). "
        + "Be concise and practical; answer in Markdown. When given selected text or a screenshot, focus on it. "
        + "For commands, prefer Fedora (dnf) and explain anything destructive before suggesting it."

    function clear() { stop(); messages = []; error = ""; }
    function stop() { if (ask.running) ask.running = false; busy = false; }

    function send(prompt) {
        prompt = prompt.trim();
        if (!prompt || busy) return;
        if (!configured) { error = "Set up AI first — Settings → AI."; return; }
        error = "";
        let text = prompt;
        if (useSelection && selection && messages.length === 0)
            text = "Selected text:\n```\n" + selection + "\n```\n\n" + prompt;
        pendingPrompt = text;
        busy = true;
        if (useScreen) {
            capture.command = ["sh", "-c", 'mkdir -p "$1" && chmod 700 "$1" && exec "$2" capture "$1/screen-$3.jpg"', "sh", runDir, Theme.lumenRoot + "/scripts/ai.sh", String(Date.now())];
            capture.running = true;
        } else begin("");
    }
    property string pendingPrompt: ""
    Process {
        id: capture
        onExited: code => {
            const f = code === 0 ? capture.command[capture.command.length - 1] : "";
            root.begin(f ? root.runDir + "/screen-" + f + ".jpg" : "");
        }
    }
    function begin(image) {
        const user = { role: "user", text: pendingPrompt };
        if (image) user.image = image;
        messages = messages.concat([user, { role: "assistant", text: "" }]);
        useScreen = false;
        const req = { provider, model, system,
                      messages: messages.slice(0, -1).map(m => Object.assign({ role: m.role, text: m.text }, m.image ? { image: m.image } : {})) };
        reqFile.setText(JSON.stringify(req));
        ask.command = [Theme.lumenRoot + "/scripts/ai.sh", "ask", reqFile.path];
        ask.running = true;
    }
    FileView { id: reqFile; path: root.runDir + "/request.json"; blockWrites: true; printErrors: false }
    Process {
        id: ask
        stdout: SplitParser {
            onRead: line => {
                let d; try { d = JSON.parse(line); } catch (e) { return; }
                if (d.e) { root.error = d.e; return; }
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
            // Drop an empty answer bubble if the request failed
            const m = root.messages;
            if (m.length && m[m.length - 1].role === "assistant" && m[m.length - 1].text === "") root.messages = m.slice(0, -1);
        }
    }

    function copy(text) { Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", text]); }

    GlobalShortcut { appid: "lumen"; name: "ai"; description: "Ask Lumen AI"; onPressed: root.toggle() }
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
