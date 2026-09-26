// AI: where "Ask Lumen" (Super+Shift+Space) gets its answers.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme
import qs.components
import qs.services
import ".."

Page {
    id: page
    title: "AI"
    subtitle: "Ask Lumen (Super+Shift+Space) can explain what you've selected, read your screen, or just answer. It's off until you pick a provider."
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
                options: [{ id: "off", label: "Off" }, { id: "ollama", label: "Local (Ollama)" }, { id: "anthropic", label: "Claude" }]
                current: Ai.provider
                onPicked: id => { Persist.data.aiProvider = id; Persist.data.aiModel = ""; Ai.refreshStatus(); }
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
    Group {
        title: "Local (Ollama)"
        visible: Ai.provider === "ollama"
        SetRow {
            icon: Ai.status.ollama ? "check_circle" : "error"
            title: Ai.status.ollama ? "Ollama is running" : "Ollama isn't running"
            description: Ai.status.ollama ? (Ai.status.ollamaModels.length + " model(s) installed")
                : "Install from ollama.com (read their install script before running it), then: ollama serve · ollama pull llama3.2 — for screenshots, a vision model such as llava or qwen2.5vl."
            Button { text: "Check again"; onActivated: Ai.refreshStatus() }
        }
        SetRow {
            visible: Ai.status.ollama && Ai.status.ollamaModels.length > 0
            icon: "tune"
            title: "Model"
            Segmented {
                width: 360
                options: Ai.status.ollamaModels.slice(0, 4).map(m => ({ id: m, label: m.replace(/:latest$/, "") }))
                current: Ai.model
                onPicked: id => Persist.data.aiModel = id
            }
        }
    }

    Group {
        title: "Privacy"
        SetRow { icon: "shield"; title: "Only when you ask"; description: "Nothing is sent until you press Enter. Selected text and screenshots are attached only when their chips are on." }
        SetRow { icon: "history_toggle_off"; title: "No history kept"; description: "Conversations live in memory and vanish when you clear them or log out." }
    }
}
