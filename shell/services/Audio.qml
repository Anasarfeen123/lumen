pragma Singleton

// Default output/input from PipeWire. Event-driven: properties update when
// PipeWire changes, whatever caused the change (keys, apps, pavucontrol).
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool ready: sink?.ready ?? false

    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property bool micMuted: source?.audio?.muted ?? false
    readonly property string deviceName: sink?.description || sink?.nickname || sink?.name || ""

    // Real output devices (not app streams), for the output picker
    readonly property var sinks: Pipewire.nodes.values.filter(n => n.isSink && !n.isStream && n.audio)
    // Apps playing sound right now (playback streams), for per-app volume
    // (properties only arrive once a node is tracked, so track every stream)
    readonly property var streams: Pipewire.nodes.values.filter(n => n.isStream)
    readonly property var apps: streams.filter(n => n.audio && (n.properties?.["media.class"] ?? "") === "Stream/Output/Audio")
    PwObjectTracker { objects: [root.sink, root.source].concat(root.sinks).concat(root.streams) }
    // One entry per app (Firefox often has several streams); system noise hidden
    readonly property var appGroups: {
        const out = [];
        for (const n of apps) {
            const p = n.properties ?? {};
            const name = p["application.name"] || n.description || n.name || "App";
            if (/speech-dispatcher|sd_dummy/i.test(name + (p["application.process.binary"] ?? ""))) continue;
            let g = out.find(x => x.name === name);
            if (!g) { g = { name, binary: p["application.process.binary"] ?? "", iconName: p["application.icon-name"] ?? "", nodes: [] }; out.push(g); }
            g.nodes.push(n);
        }
        return out;
    }
    function groupVolume(g) { return g.nodes.reduce((m, n) => Math.max(m, n.audio?.volume ?? 0), 0); }
    function groupMuted(g) { return g.nodes.every(n => n.audio?.muted ?? false); }
    function setGroupVolume(g, v) { for (const n of g.nodes) if (n.audio) { n.audio.muted = false; n.audio.volume = Math.max(0, Math.min(1, v)); } }
    function toggleGroupMute(g) { const m = !groupMuted(g); for (const n of g.nodes) if (n.audio) n.audio.muted = m; }

    function appName(node) {
        const p = node?.properties ?? {};
        return p["application.name"] || p["media.name"] || node?.description || node?.name || "App";
    }
    function appIconName(node) {
        const p = node?.properties ?? {};
        return p["application.icon-name"] || p["application.process.binary"] || p["application.name"] || "";
    }

    function label(node) { return node?.description || node?.nickname || node?.name || "Unknown"; }
    function setSink(node) { Pipewire.preferredDefaultAudioSink = node; }

    function setVolume(v) {
        if (sink?.audio) sink.audio.volume = Math.max(0, Math.min(1, v));
    }
    function nudge(delta) {
        if (sink?.audio) { sink.audio.muted = false; setVolume(volume + delta); }
    }
    function toggleMute() { if (sink?.audio) sink.audio.muted = !sink.audio.muted; }
    function toggleMicMute() { if (source?.audio) source.audio.muted = !source.audio.muted; }
}
