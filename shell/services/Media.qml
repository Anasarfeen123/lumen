pragma Singleton

// The one media player the UI talks about.
// Choice: a playing player > the one that played most recently > any with a
// track. Players with no title (idle browser tabs) are ignored.
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import Quickshell.Io

Singleton {
    id: root

    readonly property var players: Mpris.players.values.filter(p => (p.trackTitle ?? "") !== "")
    property var lastPlaying: null

    readonly property var active: players.find(p => p.isPlaying)
                                 ?? (players.includes(lastPlaying) ? lastPlaying : null)
                                 ?? players[0] ?? null

    readonly property bool present: active !== null
    readonly property bool playing: active?.isPlaying ?? false
    readonly property string title: active?.trackTitle ?? ""
    readonly property string artist: active?.trackArtist ?? ""
    readonly property string remoteArtUrl: active?.trackArtUrl ?? ""
    // Local art path: file:// URLs as-is; http(s) art is cached once under
    // $XDG_CACHE_HOME/lumen/art (the colour extractor only reads local files).
    readonly property string artCacheDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/lumen/art"
    property string artUrl: ""
    onRemoteArtUrlChanged: fetchArt()
    Component.onCompleted: fetchArt()

    function fetchArt() {
        const u = remoteArtUrl;
        if (u === "" || u.startsWith("file://") || u.startsWith("/")) { artUrl = u; return; }
        if (!/^https?:\/\//.test(u)) { artUrl = ""; return; }
        const dest = artCacheDir + "/" + Qt.md5(u);
        artFetch.dest = dest;
        artFetch.command = ["sh", "-c", 'mkdir -p "$1" && { [ -s "$2" ] || curl -sfL --max-time 6 --max-filesize 8000000 -o "$2" "$3"; }',
                            "sh", artCacheDir, dest, u];
        artFetch.running = true;
    }
    Process {
        id: artFetch
        property string dest: ""
        onExited: code => root.artUrl = code === 0 ? "file://" + dest : root.remoteArtUrl
    }

    // Album palette → one vivid, readable tint for glows and the equalizer
    ColorQuantizer {
        id: quantizer
        source: root.artUrl.startsWith("file://") ? root.artUrl : ""
        depth: 2
        rescaleSize: 64
    }
    readonly property var palette: quantizer.colors ?? []
    readonly property color tint: {
        let best = null, score = -1;
        for (const c of palette) {
            const sc = c.hsvSaturation * c.hsvValue;
            if (sc > score) { score = sc; best = c; }
        }
        if (!best) return "transparent";
        // Keep it luminous enough to glow on dark glass
        return Qt.hsla(best.hslHue < 0 ? 0 : best.hslHue, Math.max(0.45, best.hslSaturation), Math.min(0.68, Math.max(0.52, best.hslLightness)), 1);
    }
    readonly property bool hasTint: palette.length > 0
    readonly property real length: active?.length ?? 0
    readonly property bool canSeek: (active?.canSeek ?? false) && (active?.positionSupported ?? false)

    Instantiator {
        model: Mpris.players
        delegate: Connections {
            required property var modelData
            target: modelData
            function onIsPlayingChanged() { if (modelData.isPlaying) root.lastPlaying = modelData; }
        }
    }

    function toggle() { if (active?.canTogglePlaying) active.togglePlaying(); }
    function next() { if (active?.canGoNext) active.next(); }
    function previous() { if (active?.canGoPrevious) active.previous(); }
    function seekTo(fraction) { if (canSeek) active.position = fraction * length; }

    function formatTime(sec) {
        if (!isFinite(sec) || sec < 0) return "0:00";
        const m = Math.floor(sec / 60), s = Math.floor(sec % 60);
        return `${m}:${s < 10 ? "0" : ""}${s}`;
    }
}
