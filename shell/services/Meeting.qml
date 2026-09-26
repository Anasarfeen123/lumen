pragma Singleton
// Meeting mode: notice when you're on a call, and make the desktop behave.
//
//   on air   the microphone (a real input, not a speaker's monitor) or the
//            camera is in use → a red "on air" chip in the Ribbon, always,
//            like a privacy light
//   a call   on air AND it looks like a call: a meeting app or tab (Zoom,
//            Teams, Meet, Jitsi, Webex, Slack huddle, Discord…) or the camera
//            → notifications are held (Do Not Disturb, quietly), a running
//            focus timer pauses, the screen stays awake; all restored after,
//            and the island says how many notifications waited
//
// Event-driven: PipeWire says when capture streams come and go; only then
// (and every 5 s while on air) does scripts/meeting-probe.sh look closer.
// Only the main shell changes Do Not Disturb (Persist.automates).
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import qs.theme

Singleton {
    id: root

    // ── settings (~/.local/state/lumen/meeting.json) ──
    readonly property bool enabled: settings.holdNotifications
    function setEnabled(on) { settings.holdNotifications = on; }
    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/lumen/meeting.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }
        JsonAdapter {
            id: settings
            property bool holdNotifications: true
        }
    }

    // ── what's using the mic / camera ──
    property var micApps: []            // [{app, bin, pid}]
    property var cameraApps: []         // [{app, pid}]
    readonly property bool micOn: micApps.length > 0
    readonly property bool cameraOn: cameraApps.length > 0
    readonly property bool onAir: micOn || cameraOn

    // A meeting app or tab, by window class or title
    readonly property var meetingPattern: /zoom|teams|meet\.google|google meet|^meet [-–]|jitsi|webex|huddle|skype|whereby|discord|slack|signal|telegram|whatsapp/i
    readonly property var meetingWindow: Hyprland.toplevels.values.find(t => {
        const c = t.lastIpcObject?.class ?? t.wayland?.appId ?? "", title = t.title ?? "";
        return root.meetingPattern.test(c) || /(^|\s)(meet|zoom meeting|microsoft teams|jitsi meet|huddle)\b/i.test(title);
    }) ?? null
    readonly property bool callLike: micApps.some(a => meetingPattern.test(a.app + " " + a.bin))
    readonly property bool live: mockLive || (onAir && (cameraOn || callLike || meetingWindow !== null))

    // What to call it in the chip / island
    readonly property string appName: {
        if (mockLive) return mockApp;
        const t = meetingWindow?.title ?? "";
        if (/google meet|meet\.google|^meet [-–]/i.test(t)) return "Google Meet";
        if (/teams/i.test(t + (meetingWindow?.lastIpcObject?.class ?? ""))) return "Teams";
        if (/zoom/i.test(t + (meetingWindow?.lastIpcObject?.class ?? ""))) return "Zoom";
        const a = micApps.find(a => meetingPattern.test(a.app + " " + a.bin)) ?? micApps[0] ?? cameraApps[0];
        return a ? a.app.replace(/^./, c => c.toUpperCase()) : "";
    }
    readonly property string label: live ? (appName || "On a call") : cameraOn ? "Camera" : micOn ? "Mic" : ""
    readonly property string icon: cameraOn || (mockLive && mockCamera) ? "videocam" : "mic"

    // PipeWire: capture streams appearing / leaving (and the count) trigger a probe
    readonly property int inStreams: Pipewire.nodes.values.filter(n => n.type === PwNodeType.AudioInStream).length
    onInStreamsChanged: probeSoon.restart()
    Timer { id: probeSoon; interval: 400; onTriggered: root.probe() }
    // While something records (or a meeting app is open), look every 5 s — the
    // camera has no event, and streams can be corked/uncorked in place
    Timer { interval: 5000; repeat: true; running: !root.mockLive && (root.inStreams > 0 || root.meetingWindow !== null || root.onAir); onTriggered: root.probe() }
    Component.onCompleted: probe()

    function probe() {
        if (mockLive) return;
        if (!micProc.running) micProc.running = true;
        if ((inStreams > 0 || meetingWindow !== null || cameraOn) && !camProc.running) camProc.running = true;
        else if (inStreams === 0 && meetingWindow === null) cameraApps = [];
    }
    Process {
        id: micProc
        command: [Theme.lumenRoot + "/scripts/meeting-probe.sh", "mic"]
        stdout: StdioCollector { onStreamFinished: { try { const v = JSON.parse(text); if (JSON.stringify(v) !== JSON.stringify(root.micApps)) root.micApps = v; } catch (e) {} } }
    }
    Process {
        id: camProc
        command: [Theme.lumenRoot + "/scripts/meeting-probe.sh", "camera"]
        stdout: StdioCollector { onStreamFinished: { try { const v = JSON.parse(text); if (JSON.stringify(v) !== JSON.stringify(root.cameraApps)) root.cameraApps = v; } catch (e) {} } }
    }

    // ── the call: hold, pause, keep awake; restore after ──
    property var saved: null            // what we changed, to put back
    property int heldAt: 0              // notification count when the call began
    property real since: 0
    readonly property bool acts: Persist.automates || mockLive
    // A short grace so a mic blip (a voice message, a test) isn't a "call"
    Timer { id: startGrace; interval: root.mockLive ? 0 : 4000; onTriggered: if (root.live) root.begin() }
    Timer { id: endGrace; interval: root.saved?.mock ? 300 : 6000; onTriggered: if (!root.live) root.end() }
    onLiveChanged: {
        if (live) { endGrace.stop(); if (!saved) startGrace.restart(); }
        else { startGrace.stop(); if (saved) endGrace.restart(); }
    }

    function begin() {
        if (saved || !acts) return;
        since = Date.now();
        heldAt = Notifications.count;
        const hold = enabled && !Notifications.dnd;
        saved = { dnd: hold, caffeine: !Caffeine.on, countdown: Countdown.active && !Countdown.paused, mock: mockLive };
        if (hold && !mockLive) Notifications.setDnd(true, true);
        if (saved.caffeine) Caffeine.on = true;             // no dimming mid-call
        if (saved.countdown) Countdown.toggle();            // pause the focus timer
        Island.system(icon, "On a call" + (appName ? " · " + appName : ""), hold ? "Notifications held until it ends" : "", "normal");
    }
    function end() {
        if (!saved) return;
        const s = saved;
        saved = null;
        if (s.dnd && !s.mock) Notifications.setDnd(false, true);
        if (s.caffeine) Caffeine.on = false;
        if (s.countdown && Countdown.active && Countdown.paused) Countdown.toggle();
        const held = s.mock ? mockHeld : Math.max(0, Notifications.count - heldAt);
        const mins = Math.max(1, Math.round((Date.now() - since) / 60000));
        Island.system("call_end", "Call ended · " + mins + " min",
                      s.dnd || s.mock ? (held === 0 ? "No notifications waited" : held === 1 ? "1 notification held" : held + " notifications held") : "", "normal");
    }

    // ── dev mock (LUMEN_DEV): a call without a call ──
    property bool mockLive: false
    property bool mockCamera: false
    property string mockApp: "Google Meet"
    property int mockHeld: 0
    IpcHandler {
        target: "meetingTest"
        enabled: Quickshell.env("LUMEN_DEV") === "1"
        function start(): void { root.mockCamera = true; root.mockLive = true; root.micApps = [{ app: "Brave", bin: "brave", pid: 0 }]; root.cameraApps = [{ app: "brave", pid: 0 }]; }
        function mic(): void { root.mockLive = false; root.micApps = [{ app: "Voice Recorder", bin: "recorder", pid: 0 }]; root.cameraApps = []; }
        function stop(): void { root.mockHeld = 3; root.mockLive = false; root.micApps = []; root.cameraApps = []; }
        function state(): string { return JSON.stringify({ live: root.live, onAir: root.onAir, label: root.label, mic: root.micApps, camera: root.cameraApps, saved: root.saved, inStreams: root.inStreams }); }
    }
}
