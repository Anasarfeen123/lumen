// Halo: where Lumen Halo (Super+Shift+Space) gets its answers.
//
// One list of providers, because "which AI" stopped being one question:
// this computer, six clouds, and any OpenAI-compatible server you run
// yourself. Each cloud needs its own key; the keys live beside each other
// in ~/.local/state/lumen/ai/<provider>.key, mode 600, and are never shown
// again once saved. Model lists are fetched from the provider when you ask
// for them, never in the background and never on a timer.
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

    readonly property var info: Ai.providerInfo(Ai.provider) ?? ({})
    // remembered so the Halo switch can put back whatever you had before
    property string lastProvider: "ollama"

    function choose(id) {
        lastProvider = id;
        Persist.data.aiProvider = id;
        // "auto" is Ollama's own word for "pick the best installed model"
        Persist.data.aiModel = id === "ollama" ? "auto" : "";
        Ai.refreshStatus();
    }
    function ofGroup(g) { return Ai.providers.filter(p => p.group === g); }

    // ── Halo on or off ──
    Group {
        title: "Lumen Halo"
        SetRow {
            icon: "auto_awesome"
            title: Ai.provider === "off" ? "Off" : "Answers from " + page.info.label
            description: Ai.provider === "off"
                ? "Lumen never contacts a model. The shortcut does nothing."
                : (Ai.configured
                    ? "Ready. " + (Ai.local ? "Answers never leave this machine." : "Your key is stored on this computer only; usage is billed to you.")
                    : "Not set up yet — " + (page.info.group === "local" ? "start Ollama and install a model below"
                        : page.info.group === "custom" ? "add your server's address below" : "add your API key below"))
            LSwitch {
                checked: Ai.provider !== "off"
                onToggled: {
                    if (checked) page.choose(page.lastProvider);
                    else { Persist.data.aiProvider = "off"; Ai.refreshStatus(); }
                }
            }
        }
    }

    // ── Which provider ──
    Group {
        title: "On this computer"
        Repeater {
            model: page.ofGroup("local")
            delegate: SetRow {
                required property var modelData
                icon: "memory"
                title: modelData.label + (Ai.provider === modelData.id ? "  ·  in use" : "")
                description: modelData.note
                Button {
                    text: Ai.provider === modelData.id ? "In use" : (Ai.isConfigured(modelData.id) ? "Use" : "Set up")
                    primary: Ai.provider === modelData.id
                    enabled: Ai.provider !== modelData.id
                    onActivated: page.choose(modelData.id)
                }
            }
        }
    }
    Group {
        title: "Cloud models"
        Repeater {
            model: page.ofGroup("cloud")
            delegate: SetRow {
                required property var modelData
                icon: "cloud"
                title: modelData.label + (Ai.provider === modelData.id ? "  ·  in use" : "")
                description: modelData.note + (Ai.isConfigured(modelData.id) ? " · key saved" : " · key at " + modelData.site)
                Button {
                    text: Ai.provider === modelData.id ? "In use" : (Ai.isConfigured(modelData.id) ? "Use" : "Set up")
                    primary: Ai.provider === modelData.id
                    enabled: Ai.provider !== modelData.id
                    onActivated: page.choose(modelData.id)
                }
            }
        }
    }
    Group {
        title: "Your own server"
        Repeater {
            model: page.ofGroup("custom")
            delegate: SetRow {
                required property var modelData
                icon: "dns"
                title: modelData.label + (Ai.provider === modelData.id ? "  ·  in use" : "")
                description: modelData.note + (Ai.isConfigured(modelData.id) ? " · " + Ai.status.custom.url : "")
                Button {
                    text: Ai.provider === modelData.id ? "In use" : (Ai.isConfigured(modelData.id) ? "Use" : "Set up")
                    primary: Ai.provider === modelData.id
                    enabled: Ai.provider !== modelData.id
                    onActivated: page.choose(modelData.id)
                }
            }
        }
    }

    // ── The key for the chosen cloud provider ──
    // One field for whichever provider is selected, rather than a block per
    // provider: you only ever need the key of the one you are using.
    property string keyMsg: ""
    Process {
        id: keyProc
        stdinEnabled: true
        stdout: StdioCollector { onStreamFinished: page.keyMsg = text.trim() === "saved" ? "Key saved." : text.trim() === "forgotten" ? "Key removed." : page.keyMsg }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) page.keyMsg = text.trim() }
        onExited: Ai.refreshStatus()
    }
    property bool cloudChosen: Ai.provider !== "off" && page.info.group === "cloud"
    property bool hasKey: Ai.isConfigured(Ai.provider)
    Group {
        title: page.info.label ? page.info.label + " key" : "API key"
        visible: page.cloudChosen
        SetRow {
            icon: "key"
            title: page.hasKey ? "API key saved" : "API key"
            description: page.hasKey
                ? "Stored only on this computer (mode 600), never shown again."
                : "Create one at " + (page.info.site || "the provider's site") + ". Usage is billed to your account."
            Row {
                spacing: Theme.space.s2
                LField {
                    id: keyField
                    visible: !page.hasKey
                    width: 260
                    icon: "key"
                    placeholder: (page.info.key || "key") + "…"
                    input.echoMode: TextInput.Password
                    onAccepted: t => {
                        keyProc.command = [Theme.lumenRoot + "/scripts/ai.sh", "set-key", Ai.provider];
                        keyProc.running = true; keyProc.write(t + "\n"); keyProc.stdinEnabled = false;
                    }
                }
                Button {
                    text: page.hasKey ? "Remove key" : "Save"
                    onActivated: {
                        if (page.hasKey) { keyProc.command = [Theme.lumenRoot + "/scripts/ai.sh", "forget-key", Ai.provider]; keyProc.running = true; }
                        else keyField.accepted(keyField.text);
                    }
                }
            }
        }
        SetRow { visible: page.keyMsg !== ""; icon: "info"; title: page.keyMsg }
    }

    // ── Your own server: address and default model ──
    Process {
        id: customProc
        stdout: StdioCollector { onStreamFinished: Ai.refreshStatus() }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) page.keyMsg = text.trim() }
        onExited: Ai.refreshStatus()
    }
    Group {
        title: "Your server"
        visible: Ai.provider === "custom"
        SetRow {
            icon: "link"
            title: "Address"
            description: "Where your server answers. Anything that speaks the OpenAI chat format works."
            Row {
                spacing: Theme.space.s2
                LField {
                    id: urlField
                    width: 250
                    icon: "link"
                    placeholder: "http://127.0.0.1:1234/v1"
                    text: Ai.status.custom?.url ?? ""
                    // not a secret: keep it on screen so you can see what you saved
                    clearOnAccept: false
                    onAccepted: t => {
                        customProc.command = ["sh", "-c", '"$1" set-custom "$2" "$3"', "sh",
                                              Theme.lumenRoot + "/scripts/ai.sh", t.trim(), (Ai.status.custom?.model ?? "")];
                        customProc.running = true;
                    }
                }
                Button { text: "Save"; onActivated: urlField.accepted(urlField.text) }
            }
        }
        SetRow {
            icon: "deployed_code"
            title: "Default model"
            description: "Used until you pick one from the list below."
            LField {
                id: customModelField
                width: 250
                icon: "deployed_code"
                placeholder: "model name"
                text: Ai.status.custom?.model ?? ""
                clearOnAccept: false
                onAccepted: t => {
                    customProc.command = ["sh", "-c", '"$1" set-custom "$2" "$3"', "sh",
                                          Theme.lumenRoot + "/scripts/ai.sh", (Ai.status.custom?.url ?? ""), t.trim()];
                    customProc.running = true;
                }
            }
        }
    }

    // ── Which model ──
    // Ollama picks its own below (it knows what is installed). For anything
    // else the list comes from the provider, fetched only when asked.
    readonly property var modelList: Ai.modelLists[Ai.provider] ?? []
    readonly property bool cloudChosenModels: Ai.provider !== "off" && Ai.provider !== "ollama"
    Group {
        title: "Model"
        visible: page.cloudChosenModels
        SetRow {
            icon: "tune"
            title: "Model"
            description: (page.modelList.length ? (page.modelList.length + " available from " + page.info.label)
                                               : "Halo will use " + (Ai.model || "the provider's default"))
                        + (Ai.model ? " · now: " + Ai.model : "")
            Row {
                spacing: Theme.space.s2
                Button {
                    text: Ai._fetching[Ai.provider] ? "Fetching…" : (page.modelList.length ? "Refresh" : "Fetch models")
                    enabled: !Ai._fetching[Ai.provider]
                    onActivated: Ai.fetchModels(Ai.provider)
                }
            }
        }
        Repeater {
            model: page.modelList
            delegate: SetRow {
                required property var modelData
                minHeight: 44
                icon: "memory"
                title: modelData + (Ai.model === modelData ? "  ·  in use" : "")
                Button {
                    text: Ai.model === modelData ? "In use" : "Use"
                    primary: Ai.model === modelData
                    enabled: Ai.model !== modelData
                    onActivated: Persist.data.aiModel = modelData
                }
            }
        }
        SetRow {
            visible: page.modelList.length === 0
            icon: "info"
            title: "No model list fetched"
            description: "Fetching asks the provider what it has, which needs your key. Until then Halo uses " + (Ai.model || "its default") + "."
        }
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
        SetRow {
            icon: "lock"
            title: "Your keys stay here"
            description: "Each key is written to ~/.local/state/lumen/ai/<provider>.key with mode 600 and handed to curl on stdin — never on a command line, never in a log."
        }
    }
}
