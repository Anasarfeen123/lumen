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
    subtitle: ({
        general: "Lumen Halo (Super+Shift+Space): who it is, how much it says, and whether it's on at all.",
        models: "Where Halo's answers come from — a model on this computer, a cloud, or your own server.",
        voice: "Talking with Halo: speech to text, its voice, and the wake word.",
        abilities: "What Halo may do for you — run tasks, point and click, remember, watch for things.",
        day: "Wrap-ups, reminders, your calendar and mail, and the doctor keeping an eye on the system."
    })[tab] ?? ""
    // tabs = the sidebar's Halo entries (SettingsState: ai, ai-models, ai-voice, ai-abilities, ai-day)
    tabs: [{ id: "general", label: "General", icon: "auto_awesome" }, { id: "models", label: "Models", icon: "neurology" },
           { id: "voice", label: "Voice", icon: "graphic_eq" }, { id: "abilities", label: "Abilities", icon: "touch_app" },
           { id: "day", label: "Your day", icon: "wb_twilight" }]
    tab: SettingsState.page.startsWith("ai-") ? SettingsState.page.slice(3) : "general"
    onTabPicked: id => SettingsState.page = id === "general" ? "ai" : "ai-" + id
    Component.onCompleted: Ai.refreshStatus()

    readonly property var info: Ai.providerInfo(Ai.provider) ?? ({})
    // remembered so the Halo switch can put back whatever you had before
    property string lastProvider: "ollama"
    // whisper-cli and whisper-server from whisper.cpp's own source (the same
    // version Fedora packages), on the GPU through Vulkan
    readonly property string whisperBuild:
        "sudo dnf install git cmake gcc-c++ glslc vulkan-headers vulkan-loader-devel\n"
        + "[ -d /tmp/whisper.cpp ] || git clone --depth 1 --branch v1.8.1 https://github.com/ggml-org/whisper.cpp /tmp/whisper.cpp\n"
        + "cmake -S /tmp/whisper.cpp -B /tmp/whisper.cpp/build-vk -DGGML_VULKAN=ON -DBUILD_SHARED_LIBS=OFF -DCMAKE_BUILD_TYPE=Release\n"
        + "cmake --build /tmp/whisper.cpp/build-vk -j --target whisper-cli whisper-server\n"
        + "install -Dm755 /tmp/whisper.cpp/build-vk/bin/whisper-cli ~/.local/bin/whisper-cli\n"
        + "install -Dm755 /tmp/whisper.cpp/build-vk/bin/whisper-server ~/.local/bin/whisper-server\n"
    readonly property string whisperSetup:
        whisperBuild
        + "mkdir -p ~/.local/share/lumen/whisper\n"
        + "[ -s ~/.local/share/lumen/whisper/ggml-base.en.bin ] || curl -L -o ~/.local/share/lumen/whisper/ggml-base.en.bin https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en.bin\n"

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
        visible: page.tab === "general"
        title: "Lumen Halo"
        SetRow {
            icon: "auto_awesome"
            title: Ai.provider === "off" ? "Off" : "Answers from " + page.info.label.replace(/^This /, "this ")
            description: Ai.provider === "off"
                ? "Lumen never contacts a model. The shortcut does nothing."
                : (Ai.configured
                    ? "Ready. " + (Ai.local ? "Answers never leave this machine." : "Your key is stored on this computer only; usage is billed to you.")
                    : "Not set up yet — " + (page.info.group === "local" ? "start Ollama and install a model below"
                        : page.info.group === "custom" ? "add your server's address below" : "add your API key below"))
            LSwitch {
                checked: Ai.provider !== "off"
                // (the switch reports a click; checked is still the old state)
                onToggled: {
                    if (checked) { page.lastProvider = Ai.provider; Persist.data.aiProvider = "off"; Ai.refreshStatus(); }
                    else page.choose(page.lastProvider);
                }
            }
        }
    }

    // ── Halo, in person (services/Halo.qml, Voice.qml, Brief.qml, Doctor.qml) ──
    Group {
        visible: page.tab === "general"
        title: Halo.name + ", in person"
        SetRow {
            icon: "radio_button_unchecked"
            title: "Show " + Halo.name + " beside the clock"
            description: "A small ring in the island that breathes, blinks, listens and thinks. Click it to open " + Halo.name + ", right-click to talk. Its cards (the doctor, wrap-ups, reminders) appear in the island either way."
            LSwitch { checked: Persist.data.haloPresence ?? true; onToggled: Persist.data.haloPresence = !checked }
        }
        SetRow {
            icon: "sentiment_satisfied"
            title: "A face"
            description: "Two quiet eyes on the ring — they blink, glance, smile when something works and narrow when something's wrong."
            LSwitch { checked: Persist.data.haloFace ?? true; onToggled: Persist.data.haloFace = !checked }
        }
        SetRow {
            icon: "badge"
            title: "Names"
            description: "What it's called, and what it calls you" + (Halo.firstName ? " (otherwise " + Halo.firstName + ")" : "") + ". Press Enter to save."
            Row {
                spacing: 8
                LField { width: 120; icon: "auto_awesome"; placeholder: "Halo"; text: Persist.data.haloName ?? ""; clearOnAccept: false
                         onAccepted: t => Persist.data.haloName = t.trim().slice(0, 24) }
                LField { width: 130; icon: "person"; placeholder: Halo.firstName || "Your name"; text: Persist.data.haloCall ?? ""; clearOnAccept: false
                         onAccepted: t => Persist.data.haloCall = t.trim().slice(0, 32) }
            }
        }
        SetRow {
            icon: "record_voice_over"
            title: "Say my name as"
            description: "If the voice says " + (Halo.you || "your name") + " wrong, spell it the way it sounds (\"Uh-nahs\", \"Ah nas\"), press Enter, then Hear it. Only the voice uses this; written answers keep your name."
            Row {
                spacing: 8
                LField { width: 150; icon: "spatial_audio"; placeholder: Halo.you || "Your name"; text: Persist.data.haloSayName ?? ""; clearOnAccept: false
                         onAccepted: t => Persist.data.haloSayName = t.trim().slice(0, 40) }
                Button { text: "Hear it"; icon: "volume_up"; enabled: Voice.canSpeak
                         onActivated: Voice.say("Hi " + (Halo.you || "there") + ", how can I help?", true) }
            }
        }
        SetRow {
            icon: "theater_comedy"
            title: "Character"
            description: ({ calm: "Calm: plain and brief, no exclamation marks.",
                            friendly: "Friendly: warm and encouraging, still brief.",
                            jarvis: "Jarvis: composed, polite, a little dry — and a British voice when it speaks." })[Halo.character] ?? ""
            Segmented {
                width: 260
                options: [{ id: "calm", label: "Calm" }, { id: "friendly", label: "Friendly" }, { id: "jarvis", label: "Jarvis" }]
                current: Halo.character
                onPicked: id => Persist.data.haloCharacter = id
            }
        }
        SetRow {
            icon: "campaign"
            title: "Speaks up"
            description: ({ silent: "Only when it's urgent (a reminder, a call outlasting the battery) or when you ask.",
                            helpful: "When something deserves it: a hog draining the battery, low disk, a crash, your wrap-ups.",
                            companion: "Also small things: a welcome back when nothing's new, a goodnight." })[Halo.chattiness] ?? ""
                         + " Always quiet on calls, in games, fullscreen, presenting, Focus and Do Not Disturb — what waits comes back as one card."
            Segmented {
                width: 300
                options: [{ id: "silent", label: "Silent" }, { id: "helpful", label: "Helpful" }, { id: "companion", label: "Companion" }]
                current: Halo.chattiness
                onPicked: id => Persist.data.haloChattiness = id
            }
        }
    }

    Group {
        visible: page.tab === "general"
        title: "Little things"
        SetRow {
            icon: "self_improvement"
            title: "Break nudges"
            description: "After about an hour at the screen, " + Halo.name + " suggests a short break (stretch, look away, water). Never in quiet hours or during a timer."
            LSwitch { checked: Persist.data.haloBreaks ?? true; onToggled: Persist.data.haloBreaks = !checked }
        }
        SetRow {
            icon: "cake"
            title: Persist.data.haloBirthday ? "Your birthday: " + Qt.formatDate(new Date(2000, +Persist.data.haloBirthday.slice(0, 2) - 1, +Persist.data.haloBirthday.slice(3)), "d MMMM") : "Your birthday"
            description: "Tell " + Halo.name + " “my birthday is 12 March” — it wears a party hat that day. It wears headphones while music plays, and a scarf in winter."
            Button { visible: !!Persist.data.haloBirthday; text: "Forget it"; onActivated: Persist.data.haloBirthday = "" }
        }
    }

    Group {
        visible: page.tab === "voice"
        title: "Voice"
        SetRow {
            icon: Voice.canListen ? "mic" : "mic_off"
            title: Voice.canListen ? "Talk to " + Halo.name : "Talking needs whisper.cpp"
            description: Voice.canListen
                ? "Super+Alt+H (or right-click " + Halo.name + "), then just speak — it stops when you pause. Heard and written down on this computer; the recording is deleted at once. No wake word: it never listens until you ask."
                  + (Voice.canStream ? "" : "\n\nFaster, with your words appearing as you speak: rebuild whisper.cpp for the GPU with its server (Copy commands), then Check again.")
                : "Speech is recognised on this computer by whisper.cpp with a small English model (~140 MB, from the whisper.cpp project on Hugging Face). Fedora's whisper-cpp package has only the library, so whisper-cli and whisper-server are built from the project's source into ~/.local/bin, on the GPU (a few minutes, no sudo beyond the build tools). In a terminal:\n"
                  + page.whisperSetup.trim().split("\n").map(l => "  " + l).join("\n")
            Row {
                spacing: 8
                Button { visible: !Voice.canListen || !Voice.canStream; text: "Copy commands"; icon: "content_copy"
                         onActivated: Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh", Voice.canListen ? page.whisperBuild : page.whisperSetup]) }
                Button { text: "Check again"; onActivated: Voice.refresh() }
            }
        }
        SetRow {
            icon: "headset_mic"
            title: "Microphone"
            description: (Persist.data.haloMic ?? "auto") === "auto"
                ? "With Bluetooth headphones on, " + Halo.name + " listens through the laptop's mic, so your headphones keep their sound quality and replies aren't cut off."
                : "Always the headphones' mic. Bluetooth headphones switch to headset mode to use it: a second of silence each way, and mono sound while they're in it."
            Segmented {
                width: 260
                options: [{ id: "auto", label: "Automatic" }, { id: "headset", label: "Headphones' mic" }]
                current: Persist.data.haloMic ?? "auto"
                onPicked: id => Persist.data.haloMic = id
            }
        }
        SetRow {
            icon: "graphic_eq"
            title: "Recognition"
            readonly property var have: Voice.status.models ?? []
            readonly property string pick: Persist.data.haloStt ?? "balanced"
            description: (pick === "fast" ? "Quickest, but often mishears names, accents and noisy rooms (base.en)."
                        : pick === "best" ? "The most accurate, on the discrete GPU: wakes it while you talk to " + Halo.name + ", which uses more battery (large-v3-turbo)."
                        : "Accurate for most accents and still quick on the GPU (small.en).")
                + (have.indexOf(pick) < 0 ? "\nThis model isn't downloaded yet; Copy command, run it, then Check again." : "")
                + "\nApplies from your next conversation."
            Row {
                spacing: 8
                Segmented {
                    width: 280
                    options: [{ id: "fast", label: "Fast" }, { id: "balanced", label: "Balanced" }, { id: "best", label: "Best" }]
                    current: Persist.data.haloStt ?? "balanced"
                    onPicked: id => Persist.data.haloStt = id
                }
                Button {
                    visible: (Voice.status.models ?? []).indexOf(Persist.data.haloStt ?? "balanced") < 0
                    text: "Copy command"; icon: "content_copy"
                    onActivated: {
                        const f = { fast: "ggml-base.en.bin", balanced: "ggml-small.en-q5_1.bin", best: "ggml-large-v3-turbo-q5_0.bin" }[Persist.data.haloStt ?? "balanced"];
                        Quickshell.execDetached(["sh", "-c", 'printf %s "$1" | wl-copy', "sh",
                            "curl -L -o ~/.local/share/lumen/whisper/" + f + " https://huggingface.co/ggerganov/whisper.cpp/resolve/main/" + f + "\n"]);
                    }
                }
            }
        }
        SetRow {
            icon: "hearing"
            title: "Listen for “Hey " + Halo.name + "”"
            description: !Voice.canListen ? "Needs whisper.cpp first (above)."
                : "Say “Hey " + Halo.name + ", what's my next class?” — or “Hey " + Halo.name + "” and then your question. It listens in short bursts: sound is read on this computer by whisper.cpp's smallest model and deleted at once; nothing is kept or sent. A small red dot beside " + Halo.name + " shows whenever it's listening. Never on a call, in a game, or while locked; by default only while plugged in."
            Row {
                spacing: 8
                Button { visible: Persist.data.haloWake ?? false; text: (Persist.data.haloWakeBattery ?? false) ? "Also on battery ✓" : "Also on battery"
                         onActivated: Persist.data.haloWakeBattery = !(Persist.data.haloWakeBattery ?? false) }
                LSwitch { enabled: Voice.canListen; checked: Persist.data.haloWake ?? false; onToggled: Persist.data.haloWake = !checked }
            }
        }
        SetRow {
            icon: "record_voice_over"
            title: "Speak replies"
            description: (Persist.data.haloVoice ?? "off") === "headphones" ? "Out loud only while headphones are connected" + (Voice.headphones ? " (they are now)." : ".")
                       : (Persist.data.haloVoice ?? "off") === "on" ? "Out loud through the speakers too. Never during a call or while muted."
                       : "Answers stay on screen."
            Segmented {
                width: 260
                options: [{ id: "off", label: "Off" }, { id: "on", label: "On" }, { id: "headphones", label: "Headphones" }]
                current: Persist.data.haloVoice ?? "off"
                onPicked: id => Persist.data.haloVoice = id
            }
        }
        SetRow {
            icon: "graphic_eq"
            title: "How it sounds"
            description: Voice.status.tts === "piper" ? "Piper — a natural voice, on this computer (British for Jarvis, American otherwise)."
                : "espeak-ng — clear but robotic. “Natural voice” sets up Piper (offline neural speech) in a terminal you can read: its own folder, no sudo, two voices from Piper's own repository (~150 MB). It asks before doing anything."
            Row {
                spacing: 8
                LSlider { width: 120; anchors.verticalCenter: parent.verticalCenter; icon: "speed"
                          value: ((Persist.data.haloVoiceRate ?? 1) - 0.7) / 0.7
                          onMoved: v => Persist.data.haloVoiceRate = Math.round((0.7 + v * 0.7) * 20) / 20 }
                Button { visible: Voice.status.tts !== "piper"; text: "Natural voice"; icon: "graphic_eq"; primary: true
                         onActivated: Quickshell.execDetached(["kitty", "--title", "Halo · natural voice", "--hold", Theme.lumenRoot + "/scripts/halo-voice-setup.sh"]) }
                Button { text: Voice.speaking ? "Stop" : "Test"; icon: Voice.speaking ? "stop" : "play_arrow"; enabled: Voice.canSpeak
                         onActivated: Voice.speaking ? Voice.stop() : Voice.say(Halo.greeting() + " This is how I sound.", true) }
            }
        }
    }

    Group {
        visible: page.tab === "abilities"
        title: "Doing things for you"
        SetRow {
            icon: "smart_toy"
            title: "Let " + Halo.name + " carry out jobs"
            description: "Ask for a job, not just an answer — “start a 50-minute study timer and tell me my next class”, “find my DBMS notes and summarise them”, “add a to-do for the lab record and remind me at 9”. " + Halo.name + " plans it and uses Lumen's tools one step at a time; you see every step, can stop it, and anything that clicks, types, runs a command or can't be undone waits for your OK. Type /agent to ask for it directly. Works best with a larger model (Claude, or a 7B+ local one)."
            LSwitch { checked: Persist.data.haloAgent ?? true; onToggled: Persist.data.haloAgent = !checked }
        }
    }

    Group {
        visible: page.tab === "abilities"
        title: "Memory"
        SetRow {
            icon: "bookmarks"
            title: Halo.memory.length ? "Remembering " + Halo.memory.length + (Halo.memory.length === 1 ? " thing" : " things") : "Nothing remembered yet"
            description: "Say “remember that my roll number is 25BCE…” or “remember I study best at night”. It's kept on this computer, and used in answers only while this is on. “Forget …” removes one; everything is listed here."
            LSwitch { checked: Persist.data.haloUseMemory ?? true; onToggled: Persist.data.haloUseMemory = !checked }
        }
        Repeater {
            model: Halo.memory
            SetRow {
                required property var modelData
                icon: "bookmark"
                title: modelData.text
                description: "Since " + Qt.formatDate(new Date(modelData.at), "d MMM yyyy")
                Button { text: "Forget"; onActivated: Halo.forgetItem(modelData) }
            }
        }
    }

    Group {
        visible: page.tab === "abilities"
        title: "Routines and watches"
        SetRow {
            icon: "schedule"
            title: Routines.list.length ? Routines.list.length + (Routines.list.length === 1 ? " routine" : " routines") : "No routines yet"
            description: "Tell " + Halo.name + ": “every weekday at 8:30, brief me”, “whenever I plug in the charger, battery saver off”, “when I connect a monitor, focus work”, “when the battery drops to 20%, dim the screen”, “tell me when the download finishes”, “tell me when Arya replies”. Actions are things " + Halo.name + " does directly — routines never start open-ended jobs on their own."
        }
        Repeater {
            model: Routines.list
            SetRow {
                required property var modelData
                icon: modelData.once ? "notifications_active" : "repeat"
                title: Routines.describe(modelData)
                description: modelData.once ? "Once, then it's gone" : "Keeps going"
                Button { text: "Remove"; onActivated: Routines.remove(modelData.id) }
            }
        }
    }

    Group {
        visible: page.tab === "abilities" && (Object.keys(Persist.data.haloWorkflows ?? {}).length > 0)
        title: "Workflows"
        Repeater {
            model: Object.keys(Persist.data.haloWorkflows ?? {})
            SetRow {
                required property string modelData
                icon: "playlist_play"
                title: modelData
                description: ((Persist.data.haloWorkflows ?? {})[modelData] ?? []).map(s => s.say).join(" → ") + " · say “run " + modelData + "”"
                Button { text: "Remove"; onActivated: Agent.removeWorkflow(modelData) }
            }
        }
    }

    Group {
        visible: page.tab === "day"
        title: "Calendar & email"
        SetRow {
            icon: "calendar_month"
            title: Accounts.calendars.length ? Accounts.calendars.length + (Accounts.calendars.length === 1 ? " calendar" : " calendars") + " · " + Accounts.events.length + " events this month" : "Add a calendar"
            description: (Accounts.calError ? "⚠ " + Accounts.calError + "\n" : "") + "Paste a calendar's iCal link — in Google Calendar: Settings → your calendar → “Secret address in iCal format”. Read-only; events join the planner, your briefs and " + Halo.name + "'s answers. The link is kept private on this computer."
            Row {
                spacing: 8
                LField { id: calName; width: 110; icon: "label"; placeholder: "Name"; clearOnAccept: false }
                LField { id: calUrl; width: 220; icon: "link"; placeholder: "https://…/basic.ics"; clearOnAccept: false
                         onAccepted: t => Accounts.addCalendar(calName.text, t, r => { if (r.ok) { calUrl.text = ""; calName.text = ""; } }) }
                Button { text: "Add"; onActivated: Accounts.addCalendar(calName.text, calUrl.text, r => { if (r.ok) { calUrl.text = ""; calName.text = ""; } }) }
            }
        }
        Repeater {
            model: Accounts.calendars
            SetRow {
                required property var modelData
                icon: "event"
                title: modelData.name
                description: modelData.host
                Button { text: "Remove"; onActivated: Accounts.removeCalendar(modelData.name) }
            }
        }
        SetRow {
            icon: "mail"
            title: Accounts.mail.configured ? "Inbox: " + Accounts.mail.user + (Accounts.unread.length ? " · " + Accounts.unread.length + " unread" : "") : "Add your inbox"
            description: (Accounts.mailError ? "⚠ " + Accounts.mailError + "\n" : "")
                + (Accounts.mail.configured ? "Read-only: senders and subjects of unread mail, nothing marked read. " + Halo.name + " never sends mail — drafts open in Gmail for you to send."
                   : "For Gmail: turn on 2-Step Verification, then make an app password (myaccount.google.com/apppasswords) and paste it here. It's kept private on this computer (like the AI keys). Read-only; " + Halo.name + " never sends mail.")
            Row {
                spacing: 8
                visible: !Accounts.mail.configured
                LField { id: mailUser; width: 170; icon: "alternate_email"; placeholder: "you@gmail.com"; clearOnAccept: false }
                LField { id: mailPass; width: 150; icon: "key"; placeholder: "App password"; input.echoMode: TextInput.Password; clearOnAccept: false }
                Button { text: "Connect"; primary: true
                         onActivated: Accounts.setMail(/@(gmail|googlemail)\./.test(mailUser.text) ? "imap.gmail.com" : "imap." + mailUser.text.replace(/.*@/, ""), mailUser.text, mailPass.text, r => { mailPass.text = ""; }) }
            }
            Button { visible: Accounts.mail.configured; text: "Disconnect"; onActivated: Accounts.removeMail() }
        }
    }

    Group {
        visible: page.tab === "abilities"
        title: "Hands"
        SetRow {
            icon: "pan_tool_alt"
            title: "Let " + Halo.name + " use the mouse and keyboard"
            description: "Ask “click Download”, “point at the settings”, “scroll down”, “press ctrl+s”, “type …”, “close this window”. It finds things by reading the screen on this computer. Pointing and scrolling just happen; every click, key and bit of typing asks first, right where it will happen (Enter allows, Esc cancels, or allow it for 2 minutes). Move the mouse and it lets go. Never on the lock screen or over a password prompt."
            LSwitch { checked: Persist.data.haloHands ?? true; onToggled: Persist.data.haloHands = !checked }
        }
        SetRow {
            icon: "accessibility_new"
            title: "Let apps describe their buttons"
            description: "Halo finds icons without text (a gear, a ×, “New chat”) by the names apps give them for screen readers — exact, and on this computer. GTK 4 apps always do; with this on, Qt, KDE, Chromium, Brave and Electron apps do too (inside Lumen only, for apps opened after; browsers get a little slower)."
            LSwitch { checked: (Theme.tokens.prefs?.app_a11y ?? "off") === "on"; onToggled: SettingsState.lumen(["set", "app_a11y", checked ? "off" : "on"]) }
        }
        SetRow {
            icon: Hands.canClick ? "check_circle" : "info"
            title: Hands.canClick ? "Clicks and scrolling are ready" : "Clicks need ydotool"
            description: Hands.canClick ? "Through your ydotool service (its socket in your runtime folder). Typing and keys use wtype."
                : "Pointing and typing work already. For clicks and the scroll wheel, start the ydotool service: systemctl --user enable --now ydotool"
            Button { text: "Check again"; onActivated: Hands.refresh() }
        }
    }

    Group {
        visible: page.tab === "day"
        title: "Wrap-ups"
        SetRow {
            icon: "wb_sunny"
            title: "Morning brief"
            description: "At the first unlock of the day: the weather, your classes and events, an exam coming up, what came in overnight."
            LSwitch { checked: Persist.data.haloMorning ?? true; onToggled: Persist.data.haloMorning = !checked }
        }
        SetRow {
            icon: "inbox"
            title: "While you were away"
            description: "Back after 10 minutes or more: notifications by app, WhatsApp chats, finished downloads, what's next — with Summarise if there's a lot."
            LSwitch { checked: Persist.data.haloAway ?? true; onToggled: Persist.data.haloAway = !checked }
        }
        SetRow {
            icon: "nights_stay"
            title: "Evening wrap-up"
            description: "Your screen time and focus, what's still unread, tomorrow's first class and events — and Sleep mode one tap away. Ask any time: “wrap up my day”."
            Segmented {
                width: 300
                options: [{ id: "", label: "Off" }, { id: "20:00", label: "8 pm" }, { id: "21:30", label: "9:30 pm" }, { id: "23:00", label: "11 pm" }]
                current: Persist.data.haloWrapUp ?? "21:30"
                onPicked: id => Persist.data.haloWrapUp = id
            }
        }
    }

    Group {
        visible: page.tab === "day"
        title: "Watchful doctor"
        SetRow {
            icon: "stethoscope"
            title: "Keep an eye on this computer"
            description: "A light look every minute or two: an app hogging the processor or draining the battery, memory or disk running out, overheating, a service that failed, a program that crashed — each said once, with a fix you can tap. Ask any time: “how's my computer?”"
            LSwitch { checked: Persist.data.haloDoctor ?? true; onToggled: Persist.data.haloDoctor = !checked }
        }
        Repeater {
            model: Persist.data.haloDoctorIgnore ?? []
            SetRow {
                required property string modelData
                icon: "visibility_off"
                title: modelData
                description: "Never mentioned as a hog"
                Button { text: "Mention again"; onActivated: Persist.data.haloDoctorIgnore = (Persist.data.haloDoctorIgnore ?? []).filter(a => a !== modelData) }
            }
        }
    }

    Group {
        visible: page.tab === "day" && (Halo.reminders.length > 0)
        title: "Reminders"
        Repeater {
            model: Halo.reminders
            SetRow {
                required property var modelData
                required property int index
                icon: "alarm"
                title: modelData.text
                description: Planner.whenLabel(modelData.at, false)
                Button { text: "Remove"; onActivated: Halo.removeReminder(index) }
            }
        }
    }

    // ── Which provider ──
    Group {
        visible: page.tab === "models"
        title: "Smart"
        SetRow {
            icon: "alt_route"
            title: "A model for each question"
            description: Ai.providerInfo("smart").note
                + " Free tiers only, never a paid model. Uses the free providers you've added a key for below (Gemini, Groq, Mistral)"
                + (Ai.isConfigured("ollama") ? " and this computer." : "; this computer too once a local model is installed.")
                + "\nWhat you ask, and any screen, clipboard or files you share, can go to those free providers, which may use it to improve their models."
            Button {
                text: Ai.smart ? "In use" : (Ai.isConfigured("smart") ? "Use" : "Add a key first")
                primary: Ai.smart
                enabled: !Ai.smart && Ai.isConfigured("smart")
                onActivated: page.choose("smart")
            }
        }
        Repeater {
            // today's use of each free provider
            model: Ai.smart ? AiRouter.summary() : []
            delegate: SetRow {
                required property var modelData
                icon: modelData.resting ? "hourglass_top" : "data_usage"
                title: modelData.label
                description: modelData.resting ? "Resting: its free limit was reached. Back at " + modelData.until + "."
                    : modelData.req + (modelData.rpd ? " of about " + modelData.rpd : "") + " requests today"
                      + (modelData.tpd ? " · " + Math.round(modelData.tok / 1000) + "k of about " + Math.round(modelData.tpd / 1000) + "k tokens" : "")
            }
        }
    }
    Group {
        visible: page.tab === "models"
        title: "On this computer"
        Repeater {
            model: page.ofGroup("local")
            delegate: SetRow {
                required property var modelData
                icon: "memory"
                title: modelData.label
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
        visible: page.tab === "models"
        title: "Cloud models"
        Repeater {
            model: page.ofGroup("cloud")
            delegate: SetRow {
                required property var modelData
                icon: "cloud"
                title: modelData.label
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
        visible: page.tab === "models"
        title: "Your own server"
        Repeater {
            model: page.ofGroup("custom")
            delegate: SetRow {
                required property var modelData
                icon: "dns"
                title: modelData.label
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
        visible: page.tab === "models" && (page.cloudChosen)
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
        visible: page.tab === "models" && (Ai.provider === "custom")
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
        visible: page.tab === "models" && (page.cloudChosenModels)
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
        visible: page.tab === "models" && (Ai.provider === "ollama")
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
        visible: page.tab === "models" && (Ai.provider === "ollama" && Ai.status.ollama)
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
        visible: page.tab === "models"
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
