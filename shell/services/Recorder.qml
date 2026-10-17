pragma Singleton
// "Watch me": Halo notes how you set things up, then keeps it as a workflow.
//   "watch me" / "record a workflow"     → do your setup the way you like it
//   "save it as coding mode"             → a workflow ("run coding mode")
//   "stop watching" / "cancel"           → forget it
// What it notes (Lumen-level, never keystrokes or what's inside apps): the
// apps you open and on which workspace, Focus modes, Do Not Disturb, Caffeine,
// night light, music playing. Replays through Halo's own actions (Agent.replay).
import QtQuick
import Quickshell
import Quickshell.Hyprland

Singleton {
    id: root
    property bool recording: false
    property var steps: []              // [{ tool: "do"|"wait", args, say }]
    property real started: 0

    function start() {
        steps = [];
        recordedWs = -1;
        started = Date.now();
        recording = true;
        Halo.say({ key: "recorder", icon: "radio_button_checked", title: "Watching", text: "Set things up the way you like — open apps, move to workspaces, pick a Focus mode. Then say “save it as …”.",
                   level: "asked", duration: 9000, tone: "normal",
                   actions: [{ label: "Stop", icon: "stop_circle", run: () => root.cancel() }] });
    }
    function cancel() { recording = false; steps = []; }
    function save(name) {
        recording = false;
        const clean = steps.filter((s, i) => !(s.tool === "wait" && (i === 0 || steps[i - 1].tool === "wait")));
        if (!clean.length) { Halo.say({ key: "recorder", icon: "info", title: "Nothing to save", text: "I didn't see you open apps or change modes.", level: "asked" }); return; }
        const w = Object.assign({}, Persist.data.haloWorkflows ?? {});
        w[name.trim()] = clean;
        Persist.data.haloWorkflows = w;
        Halo.say({ key: "recorder", icon: "playlist_add_check", title: "Saved “" + name.trim() + "”", text: clean.filter(s => s.tool !== "wait").map(s => s.say).join(" → ") + "\nSay “run " + name.trim() + "”.",
                   level: "asked", tone: "happy", duration: 12000 });
    }
    function add(command, say) {
        if (!recording) return;
        const s = steps.slice();
        if (s.length && s[s.length - 1].args?.command === command) return;
        s.push({ tool: "do", args: { command }, say });
        if (/^open /.test(command)) s.push({ tool: "wait", args: { seconds: 1.5 }, say: "Waiting for it to open" });
        steps = s;
    }

    // ── what it watches ──
    property int recordedWs: -1             // the workspace the last recorded app went to
    Connections {
        target: Hyprland
        enabled: root.recording
        function onRawEvent(ev) {
            if (ev.name === "openwindow") {
                const p = ev.data.split(",");               // address,workspace,class,title
                const cls = p[2] ?? "";
                if (!cls || cls === "org.quickshell") return;
                const app = Apps.entryFor(cls)?.name ?? cls;
                const ws = parseInt(p[1]);
                // every app goes back to its workspace (the first one too)
                if (ws > 0 && ws !== root.recordedWs) { root.add("go to workspace " + ws, "Workspace " + ws); root.recordedWs = ws; }
                root.add("open " + app, "Open " + app);
            }
        }
    }
    Connections { target: Focus; enabled: root.recording; function onModeChanged() { root.add(Focus.mode === "off" ? "focus off" : "focus " + Focus.mode, "Focus: " + Focus.mode); } }
    Connections { target: Notifications; enabled: root.recording; function onDndChanged() { root.add("do not disturb " + (Notifications.dnd ? "on" : "off"), "Do Not Disturb " + (Notifications.dnd ? "on" : "off")); } }
    Connections { target: Caffeine; enabled: root.recording; function onOnChanged() { root.add(Caffeine.on ? "stay awake" : "caffeine off", Caffeine.on ? "Stay awake" : "Caffeine off"); } }
    Connections { target: NightLight; enabled: root.recording; ignoreUnknownSignals: true; function onEnabledChanged() { root.add("night light " + (NightLight.enabled ? "on" : "off"), "Night light " + (NightLight.enabled ? "on" : "off")); } }
    Connections { target: Media; enabled: root.recording; function onPlayingChanged() { if (Media.playing) root.add("play", "Play music"); } }

    // ── what Halo understands ──
    function intent(q) {
        const l = q.toLowerCase().replace(/[.!]+$/, "").trim();
        let m;
        if (/^(watch me|watch what i do|record (a |my )?(workflow|setup|routine)|start recording (a |my )?(workflow|setup)|learn (this|my setup))$/.test(l))
            return { glyph: "radio_button_checked", title: "Watching", own: () => root.start() };
        if (recording && (m = /^(?:(?:stop(?: recording| watching)?(?:,| and)? )?(?:save|call|name|keep) (?:it|this|that)(?: as)? |stop(?: recording| watching)?(?:,| and)? (?:call it |save as ))["“]?(.+?)["”]?$/.exec(l)))
            return { glyph: "playlist_add_check", title: "Saved", own: () => root.save(m[1]) };
        if (recording && /^(stop watching|stop recording|cancel|never ?mind)$/.test(l))
            return { glyph: "stop_circle", title: "Stopped watching", plain: true, run: () => root.cancel() };
        return null;
    }
}
