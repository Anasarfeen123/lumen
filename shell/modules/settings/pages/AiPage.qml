// Halo: where Lumen Halo (Super+Shift+Space) gets its answers, and the
// local models it can use (download, remove, choose).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "Halo"
    subtitle: "Lumen Halo (Super+Shift+Space) explains what you've selected, reads your screen, checks your system, writes commands and commit messages. It's off until you pick where answers come from."
    Component.onCompleted: Ai.refreshStatus()

    Group {
        title: "Provider"
        SetRow {
            icon: "smart_toy"
            title: "Answers from"
            description: Ai.provider === "ollama" ? "Local models — nothing leaves this computer"
                       : Ai.provider === "anthropic" ? "Claude, with your own Anthropic API key"
                       : "Off — Lumen never contacts a model"
            Segmented {
                width: 330
                options: [{ id: "off", label: "Off" }, { id: "ollama", label: "This computer" }, { id: "anthropic", label: "Claude" }]
                current: Ai.provider
                onPicked: id => { Persist.data.aiProvider = id; Persist.data.aiModel = id === "ollama" ? "auto" : ""; Ai.refreshStatus(); }
            }
        }
    }

    // ── Claude ──
    property string keyMsg: ""
    Process {
        id: keyProc
        stdinEnabled: true
        stdout: StdioCollector { onStreamFinished: page.keyMsg = text.trim() === "saved" ? "Key saved." : text.trim() === "forgotten" ? "Key removed." : page.keyMsg }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) page.keyMsg = text.trim() }
        onExited: Ai.refreshStatus()
    }
    Group {
        title: "Claude (Anthropic)"
        visible: Ai.provider === "anthropic"
        SetRow {
            icon: "key"
            title: Ai.status.anthropic ? "API key saved" : "API key"
            description: Ai.status.anthropic ? "Stored only on this computer (mode 600), never shown again."
                       : "Create one at console.anthropic.com → API keys. Usage is billed to your account."
            Row {
                spacing: Theme.space.s2
                LField {
                    id: keyField
                    visible: !Ai.status.anthropic
                    width: 260
                    icon: "key"
                    placeholder: "sk-ant-…"
                    input.echoMode: TextInput.Password
                    onAccepted: t => { keyProc.command = [Theme.lumenRoot + "/scripts/ai.sh", "set-key", "anthropic"]; keyProc.running = true; keyProc.write(t + "\n"); keyProc.stdinEnabled = false; }
                }
                Button {
                    text: Ai.status.anthropic ? "Remove key" : "Save"
                    onActivated: {
                        if (Ai.status.anthropic) { keyProc.command = [Theme.lumenRoot + "/scripts/ai.sh", "forget-key", "anthropic"]; keyProc.running = true; }
                        else keyField.accepted(keyField.text);
                    }
                }
            }
        }
        SetRow {
            icon: "tune"
            title: "Model"
            description: Ai.model === "claude-haiku-4-5-20251001" ? "Fastest and cheapest" : Ai.model === "claude-opus-5-5" ? "Most capable, slower" : "Balanced — a good default"
            Segmented {
                width: 330
                options: [{ id: "claude-haiku-4-5-20251001", label: "Haiku 4.5" }, { id: "claude-sonnet-5", label: "Sonnet 5" }, { id: "claude-opus-5-5", label: "Opus 5.5" }]
                current: Ai.model
                onPicked: id => Persist.data.aiModel = id
            }
        }
        SetRow { visible: page.keyMsg !== ""; icon: "info"; title: page.keyMsg }
    }

    // ── Ollama ──
    // Downloads go through ai.sh pull (Ollama's own registry); progress shows here and in the island
    property string pulling: ""
    property int pullPct: -1
    property string pullMsg: ""
    Process {
        id: pullProc
        stdout: SplitParser {
            onRead: line => {
                let d; try { d = JSON.parse(line); } catch (e) { return; }
                if (d.e) { page.pullMsg = d.e; return; }
                if (d.p !== undefined) page.pullPct = d.p;
                page.pullMsg = d.st ?? page.pullMsg;
                Island.progress("pull", "download", "Downloading " + page.pulling, d.p ?? -1, d.st ?? "");
            }
        }
        onExited: code => {
            const ok = code === 0 && page.pullMsg === "success";
            Island.push({ kind: "system", key: "progress:pull", priority: Island.priority.system, duration: 3500, queueable: true, force: true,
                          data: { icon: ok ? "task_alt" : "error", title: ok ? page.pulling + " is ready" : "Download stopped", detail: ok ? "Halo can use it now" : page.pullMsg, tone: ok ? "success" : "error" } });
            page.pulling = ""; page.pullPct = -1;
            Ai.refreshStatus();
        }
    }
    function pull(m) { if (pullProc.running) return; pulling = m; pullPct = 0; pullMsg = "starting"; pullProc.command = [Theme.lumenRoot + "/scripts/ai.sh", "pull", m]; pullProc.running = true; }
    property string removing: ""
    function remove(m) {
        if (removing !== m) { removing = m; removeTimer.restart(); return; }
        removing = "";
        Quickshell.execDetached(["sh", "-c", '"$1" rm "$2"; sleep 0.5', "sh", Theme.lumenRoot + "/scripts/ai.sh", m]);
        refreshLater.restart();
    }
    Timer { id: removeTimer; interval: 4000; onTriggered: page.removing = "" }
    Timer { id: refreshLater; interval: 1200; onTriggered: Ai.refreshStatus() }

    // Good local models for a laptop, smallest first
    readonly property var recommended: [
        { name: "llama3.2:3b", size: "2.0 GB", note: "Fast everyday answers; fits most GPUs" },
        { name: "gemma3:4b", size: "3.3 GB", note: "Reads your screen and images; good all-rounder" },
        { name: "qwen2.5-coder:3b", size: "1.9 GB", note: "Code, commands and commit messages" },
        { name: "qwen3:8b", size: "5.2 GB", note: "Smarter, slower; needs 8 GB of video memory to be quick" },
    ]

    Group {
        title: "On this computer (Ollama)"
        visible: Ai.provider === "ollama"
        SetRow {
            icon: Ai.status.ollama ? "check_circle" : "error"
            title: Ai.status.ollama ? "Ollama is running" : "Ollama isn't running"
            description: Ai.status.ollama ? ((Ai.status.ollamaModels ?? []).length + " model(s) installed · answers never leave this computer")
                : "Install it from your distribution (Fedora: sudo dnf install ollama) and start it: systemctl enable --now ollama"
            Button { text: "Check again"; onActivated: Ai.refreshStatus() }
        }
        SetRow {
            visible: (Ai.status.ollamaModels ?? []).length > 1
            icon: "auto_awesome"
            title: "Automatic model"
            description: Ai.auto ? "On — " + Ai.textModel + " for text" + (Ai.visionModel && Ai.visionModel !== Ai.textModel ? ", " + Ai.visionModel + " when it needs to see your screen" : "")
                                 : "Off — Halo always uses " + Ai.model
            LSwitch { checked: Ai.auto; onToggled: Persist.data.aiModel = !checked ? "auto" : Ai.textModel }
        }
        Repeater {
            model: Ai.status.ollamaInfo ?? []
            delegate: SetRow {
                required property var modelData
                icon: modelData.vision ? "visibility" : "memory"
                title: modelData.name + ((Ai.status.loaded ?? []).includes(modelData.name) ? "  · loaded" : "")
                description: [modelData.params, (modelData.size / 1e9).toFixed(1) + " GB", modelData.vision ? "reads images" : "text"].filter(x => x).join(" · ")
                Row {
                    spacing: Theme.space.s2
                    Button {
                        visible: !Ai.auto
                        text: Ai.model === modelData.name ? "In use" : "Use"
                        primary: Ai.model === modelData.name
                        onActivated: Persist.data.aiModel = modelData.name
                    }
                    Button { text: page.removing === modelData.name ? "Press again to remove" : "Remove"; onActivated: page.remove(modelData.name) }
                }
            }
        }
    }
    Group {
        title: "Download a model"
        visible: Ai.provider === "ollama" && Ai.status.ollama
        SetRow {
            visible: page.pulling !== ""
            icon: "download"
            title: "Downloading " + page.pulling + (page.pullPct >= 0 ? " · " + page.pullPct + "%" : "")
            description: page.pullMsg
        }
        Repeater {
            model: page.recommended.filter(r => !(Ai.status.ollamaModels ?? []).includes(r.name))
            delegate: SetRow {
                required property var modelData
                icon: "deployed_code"
                title: modelData.name
                description: modelData.size + " · " + modelData.note
                Button { text: "Download"; enabled: page.pulling === ""; onActivated: page.pull(modelData.name) }
            }
        }
        SetRow {
            icon: "search"
            title: "Another model"
            description: "Any name from ollama.com/library, e.g. mistral:7b or phi4-mini"
            LField { id: otherModel; width: 200; icon: "deployed_code"; placeholder: "name:tag"; onAccepted: t => page.pull(t.trim()) }
        }
    }

    Group {
        title: "Privacy"
        SetRow { icon: "shield"; title: "Only when you ask"; description: "Nothing is sent until you press Enter. Selected text and screenshots are attached only when their chips are on." }
        SetRow { icon: "history_toggle_off"; title: "No history kept"; description: "Conversations live in memory and vanish when you clear them or log out." }
    }
}
