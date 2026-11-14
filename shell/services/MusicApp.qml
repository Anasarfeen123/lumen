pragma Singleton

// ytm-rs (github.com/grapedjuice/ytm-rs), the native YouTube Music app, as part of
// Lumen. Playback, the island, the bar chip, lyrics and media keys already work
// through MPRIS (services/Media.qml); this adds what MPRIS can't carry:
//
// - its colours follow Lumen's: ytm-rs reads `theme.conf` from its data folder
//   (a `name = #rrggbb` per line) and reloads it within seconds. Lumen writes it
//   when the theme or wallpaper changes, and never overwrites a theme.conf you
//   wrote yourself — only one that starts with Lumen's marker line.
//   (In ytm-rs, Settings › Appearance › Accent colour › From file turns it on.)
// - Settings → Sound: "Match Lumen's colours" (Persist.ytmTheme).
// - the music PiP (modules/pip/MusicPip.qml): a small player on top, in a
//   corner, across workspaces. ytm-rs's own mini player can't do that here
//   (its window is tiled in the music scratchpad, and Wayland apps can't keep
//   themselves on top). It opens when you hide the music scratchpad while
//   music plays (Persist.musicPip), with Ctrl+Super+P on the music app, or
//   Halo "mini player"; opening the scratchpad puts it away.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs.theme

Singleton {
    id: root

    readonly property string dataDir: (Quickshell.env("XDG_DATA_HOME") || Quickshell.env("HOME") + "/.local/share") + "/ytm-rs"
    readonly property string marker: "# Written by Lumen (Settings → Sound → Match Lumen's colours). Edit this line out to keep your own."
    readonly property bool enabled: Persist.data.ytmTheme ?? true

    function hex(c) {
        const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2);
        return "#" + h(c.r) + h(c.g) + h(c.b);
    }
    readonly property string conf: [
        marker,
        "accent = " + hex(Theme.accent),
        "background = " + hex(Theme.bg),
        "surface = " + hex(Theme.surface),
        "menu = " + hex(Theme.surfaceElevated),
        "text = " + hex(Theme.text),
        "text-dim = " + hex(Theme.textSecondary),
        "text-faint = " + hex(Theme.textMuted)
    ].join("\n") + "\n"

    onConfChanged: soon.restart()
    onEnabledChanged: soon.restart()
    Component.onCompleted: soon.restart()
    Timer { id: soon; interval: 1500; onTriggered: root.write() }

    function write() {
        if (!enabled) return;
        writer.command = ["sh", "-c",
            // only where ytm-rs is set up; only over our own file (or none); only when it changed
            'd="$1"; f="$d/theme.conf"; [ -d "$d" ] || exit 0; ' +
            'if [ -e "$f" ] && ! head -n 1 "$f" | grep -qF "$2"; then exit 3; fi; ' +
            'printf "%s" "$3" | cmp -s - "$f" 2>/dev/null && exit 0; ' +
            'printf "%s" "$3" > "$f.lumen" && mv -f "$f.lumen" "$f"',
            "sh", dataDir, marker, conf];
        writer.running = true;
    }
    // ── the music PiP ──
    property bool pipShown: false
    readonly property bool pipVisible: pipShown && Media.present && !Pip.videoShown && !scratchVisible
    property string pipCorner: Persist.data.musicPipCorner ?? "br"
    onPipCornerChanged: if (Persist.data.musicPipCorner !== pipCorner) Persist.data.musicPipCorner = pipCorner
    readonly property bool autoPip: Persist.data.musicPip ?? true
    property bool scratchVisible: false
    function showPip() {
        if (!Media.present) { Island.system("music_off", "Nothing playing", "Start something in your music app first"); return; }
        if (scratchVisible) hideScratch();
        pipShown = true;
    }
    function closePip() { pipShown = false; }
    function hideScratch() { Quickshell.execDetached(["hyprctl", "dispatch", "hl.dsp.workspace.toggle_special([[music]])"]); }
    function openApp() { pipShown = false; if (!scratchVisible) hideScratch(); }      // (the same toggle opens it)
    // the music scratchpad shown or hidden on any monitor
    Connections {
        target: Hyprland
        function onRawEvent(ev) {
            if (ev.name !== "activespecial") return;              // "special:music,DP-1" shown · ",DP-1" hidden
            const shown = ev.data.split(",")[0] === "special:music";
            if (shown === root.scratchVisible) return;
            if (!shown && root.scratchVisible && root.autoPip && Media.playing) root.pipShown = true;
            if (shown) root.pipShown = false;
            root.scratchVisible = shown;
        }
    }
    // the player went away
    Connections { target: Media; function onPresentChanged() { if (!Media.present) root.pipShown = false; } }

    IpcHandler {
        target: "musicpip"
        function open(): void { root.showPip(); }
        function close(): void { root.closePip(); }
        function state(): string { return JSON.stringify({ shown: root.pipShown, visible: root.pipVisible, scratch: root.scratchVisible, corner: root.pipCorner, auto: root.autoPip }); }
    }

    property bool ownFile: true             // false: a theme.conf of your own is there, left alone
    Process { id: writer; onExited: code => root.ownFile = code !== 3 }
}
