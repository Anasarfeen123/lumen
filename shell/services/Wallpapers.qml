pragma Singleton

// Wallpaper library + picker state. The list comes from
// `scripts/wallpaper.sh list`; thumbnails are made in the background by
// `wallpaper.sh thumbs` (480 px, cached by path hash) the first time the
// picker opens. Applying goes through `wallpaper.sh set` so the shell's
// cross-fade, the overview tiles and the lock screen all follow.
//
// "Match accent": the accent hue is taken from the wallpaper's most vivid
// colour (OKLCH hue, kept clear of success/warning/error by build.py).
import QtQuick
import Quickshell
import Quickshell.Io
import qs.theme

Singleton {
    id: root

    property bool open: false
    property var items: []                  // [{ category, path, thumb }]
    property string current: ""
    property string category: "All"
    readonly property var categories: ["All"].concat([...new Set(items.map(i => i.category))])
    readonly property var visibleItems: category === "All" ? items : items.filter(i => i.category === category)
    readonly property bool matchAccent: (Theme.tokens.accent_name ?? "") === "wallpaper"
    // build.py falls back to Ion's hue (212) when no wallpaper hue is stored
    readonly property bool hueKnown: (Theme.tokens.accent_hue ?? 212) !== 212

    readonly property string script: Theme.lumenRoot + "/scripts/wallpaper.sh"
    readonly property string thumbDir: (Quickshell.env("XDG_CACHE_HOME") || (Quickshell.env("HOME") + "/.cache")) + "/lumen/thumbs"
    property int thumbsVersion: 0           // bumps when thumbnails finish → images reload

    function thumbFor(path) { return "file://" + thumbDir + "/" + Qt.md5(path) + ".jpg?v=" + thumbsVersion; }

    function toggle() { open ? hide() : show(); }
    function show() { refresh(); open = true; }
    function hide() { open = false; }

    function refresh() {
        if (!lister.running) lister.running = true;
    }

    function apply(path) {
        Quickshell.execDetached([script, "set", path]);
        current = path;
        if (matchAccent) quantizer.source = "file://" + path;
    }

    function random() {
        const pool = items.filter(i => i.path !== current);
        if (pool.length > 0) apply(pool[Math.floor(Math.random() * pool.length)].path);
    }

    function setMatchAccent(on) {
        if (on) {
            Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen", "accent", "wallpaper"]);
            if (current !== "") quantizer.source = "file://" + current;
        } else {
            Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen", "accent", "ion"]);
        }
    }

    Process {
        id: lister
        command: [root.script, "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const line of text.split("\n")) {
                    const tab = line.indexOf("\t");
                    if (tab > 0) out.push({ category: line.slice(0, tab), path: line.slice(tab + 1) });
                }
                root.items = out;
                if (!thumber.running) thumber.running = true;
            }
        }
    }

    Process {
        id: thumber
        command: [root.script, "thumbs"]
        onExited: root.thumbsVersion++
    }

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/lumen/wallpaper"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            root.current = text().trim();
            // Accent follows the wallpaper but no hue was ever derived → derive it now
            if (root.matchAccent && !root.hueKnown && root.current !== "") quantizer.source = "file://" + root.current;
        }
    }

    // ── Accent from wallpaper ──
    ColorQuantizer {
        id: quantizer
        depth: 3
        rescaleSize: 64
        onColorsChanged: {
            if (!root.matchAccent || colors.length === 0) return;
            let best = null, score = -1;
            for (const c of colors) {
                const sc = c.hsvSaturation * Math.min(1, c.hsvValue * 1.4);
                if (sc > score) { score = sc; best = c; }
            }
            if (!best || score < 0.08) return;     // near-grey wallpaper: keep the current hue
            Quickshell.execDetached([Theme.lumenRoot + "/bin/lumen", "accent-hue", root.oklchHue(best).toFixed(1)]);
        }
    }

    // sRGB colour → OKLCH hue in degrees (same space the tokens use)
    function oklchHue(c) {
        const lin = v => v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        const r = lin(c.r), g = lin(c.g), b = lin(c.b);
        const l = Math.cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b);
        const m = Math.cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b);
        const s = Math.cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b);
        const A = 1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s;
        const B = 0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s;
        return (Math.atan2(B, A) * 180 / Math.PI + 360) % 360;
    }
}
