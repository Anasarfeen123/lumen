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
import QtQuick
import Quickshell
import Quickshell.Io
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
    property bool ownFile: true             // false: a theme.conf of your own is there, left alone
    Process { id: writer; onExited: code => root.ownFile = code !== 3 }
}
