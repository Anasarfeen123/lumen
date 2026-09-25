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
    PwObjectTracker { objects: [root.sink, root.source].concat(root.sinks) }

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
