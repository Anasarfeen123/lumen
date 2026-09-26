pragma Singleton

// Lumen design tokens for QML.
// Reads generated/tokens.json (written by theme/build.py) and watches it, so
// `lumen theme <name>` recolours the running shell live — no restart.
// Fallback values are the Dark theme, used only if the file can't be read.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string lumenRoot: Quickshell.env("LUMEN_ROOT") || (Quickshell.env("HOME") + "/.config/lumen")

    property var tokens: ({})

    FileView {
        path: root.lumenRoot + "/generated/tokens.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root.tokens = JSON.parse(text());
            } catch (e) {
                console.warn("Theme: tokens.json unreadable, keeping previous values:", e);
            }
        }
    }

    readonly property var _c: tokens.colors ?? ({})
    readonly property var _edge: tokens.edge ?? ({ base: "ffffff", border: 0.08, strong: 0.14 })
    readonly property var _glass: tokens.glass ?? ({ chrome_alpha: 0.72, panel_alpha: 0.80 })
    readonly property var _motion: tokens.motion ?? ({})
    readonly property var _curves: _motion.curves ?? ({})
    readonly property var _type: tokens.type ?? ({})
    readonly property var _space: tokens.space ?? ({})
    readonly property var _radius: tokens.radius ?? ({})
    readonly property var _island: tokens.island ?? ({})
    readonly property var _locale: tokens.locale ?? ({})

    // ── Time ──
    readonly property bool clock12h: (_locale.clock ?? "12h") === "12h"
    readonly property string timeFormatFull: clock12h ? "h:mm AP" : "HH:mm"
    // Digits only ("12:07"). Qt uses 12-hour digits only when AP is in the
    // same format string, so format the full time and strip the period.
    function timeDigits(d) { return Qt.formatDateTime(d, timeFormatFull).replace(/\s*[AaPp][Mm]$/, ""); }
    function timePeriod(d) { return clock12h ? Qt.formatDateTime(d, "AP") : ""; }

    function hex(name, fallback) { return "#" + (_c[name] ?? fallback); }
    function withAlpha(c, a) { return Qt.rgba(c.r, c.g, c.b, a); }

    // ── Colour roles (DESIGN.md §2) ──
    readonly property bool dark: (tokens.mode ?? "dark") === "dark"
    readonly property color bg: hex("bg", "0d1014")
    readonly property color surface: hex("surface", "161a1f")
    readonly property color surfaceElevated: hex("surface_elevated", "1f2329")
    readonly property color surfaceHover: hex("surface_hover", "2a2e34")
    readonly property color text: hex("text", "f0f2f4")
    readonly property color textSecondary: hex("text_secondary", "b3b8be")
    readonly property color textMuted: hex("text_muted", "83888f")
    // Evening (Settings → Appearance → Adapt to the time of day): after sunset
    // the accent warms a little, motion slows a touch and glows soften.
    // Set by the shell (SessionSources) from the local sunset time.
    property bool evening: false
    readonly property color accent: evening ? Qt.tint(hex("accent", "52d1e9"), Qt.rgba(1, 0.62, 0.32, 0.14)) : hex("accent", "52d1e9")
    readonly property color accentHover: evening ? Qt.tint(hex("accent_hover", "64e2f9"), Qt.rgba(1, 0.62, 0.32, 0.14)) : hex("accent_hover", "64e2f9")
    readonly property real glow: evening ? 0.6 : 1          // multiply decorative glows by this
    readonly property color onAccent: hex("on_accent", "0b181b")
    readonly property color success: hex("success", "71d790")
    readonly property color warning: hex("warning", "f1c961")
    readonly property color error: hex("error", "f66d67")

    readonly property color _edgeBase: "#" + _edge.base
    readonly property color border: withAlpha(_edgeBase, _edge.border)
    readonly property color borderStrong: withAlpha(_edgeBase, _edge.strong)

    // ── Glass (DESIGN.md §6) ──
    readonly property color glassChrome: withAlpha(surface, _glass.chrome_alpha)
    readonly property color glassPanel: withAlpha(surface, _glass.panel_alpha)
    readonly property color shadowColor: Qt.rgba(0, 0, 0, dark ? 0.28 : 0.14)

    // ── Type (DESIGN.md §3) ──
    readonly property string fontUi: _type.ui ?? "Inter"
    readonly property string fontMono: _type.mono ?? "JetBrainsMono Nerd Font"
    readonly property string fontIcon: "Material Symbols Rounded"
    readonly property QtObject size: QtObject {
        readonly property real display: 64
        readonly property real title: 20
        readonly property real heading: 15
        readonly property real body: 13
        readonly property real caption: 11
        readonly property real icon: 20
        readonly property real iconSmall: 18
    }

    // ── Space & geometry (DESIGN.md §4–5) ──
    readonly property QtObject space: QtObject {
        readonly property int s1: root._space.s1 ?? 4
        readonly property int s2: root._space.s2 ?? 8
        readonly property int s3: root._space.s3 ?? 12
        readonly property int s4: root._space.s4 ?? 16
        readonly property int s5: root._space.s5 ?? 20
        readonly property int s6: root._space.s6 ?? 24
        readonly property int s8: root._space.s8 ?? 32
    }
    readonly property QtObject radius: QtObject {
        readonly property int xs: root._radius.xs ?? 6
        readonly property int sm: root._radius.sm ?? 10
        readonly property int md: root._radius.md ?? 12
        readonly property int lg: root._radius.lg ?? 20
        readonly property int island: root._radius.island ?? 28
    }
    readonly property QtObject island: QtObject {
        readonly property int height: root._island.height ?? 38
        readonly property int idleMinWidth: root._island.idle_min_width ?? 120
        readonly property int expandedWidth: root._island.expanded_width ?? 420
        readonly property int expandedHeight: root._island.expanded_height ?? 96
        readonly property int mediaHeight: root._island.media_height ?? 132
        readonly property int maxCompactWidth: root._island.max_compact_width ?? 360
        readonly property int workspaceDebounce: root._island.workspace_debounce ?? 150
        readonly property int startupGrace: root._island.startup_grace ?? 2000
    }
    readonly property int barHeight: island.height
    readonly property int edgeGap: space.s2      // shell surfaces ↔ screen edge

    // ── Motion (DESIGN.md §7) ──
    readonly property bool reducedMotion: _motion.reduced ?? false
    readonly property QtObject motion: QtObject {
        readonly property real _pace: root.evening ? 1.15 : 1
        readonly property int micro: root.reducedMotion ? 0 : Math.round((root._motion.micro ?? 120) * _pace)
        readonly property int normal: root.reducedMotion ? 100 : Math.round((root._motion.normal ?? 220) * _pace)
        readonly property int large: root.reducedMotion ? 100 : Math.round((root._motion.large ?? 320) * _pace)
        readonly property real exitRatio: root._motion.exit_ratio ?? 0.7
        readonly property real springStrength: root._motion.spring_strength ?? 4.2
        readonly property real springDamping: root._motion.spring_damping ?? 0.34
    }
    // Easing.Bezier wants [x1, y1, x2, y2, 1, 1]
    function _curve(name, fb) { const p = _curves[name] ?? fb; return [p[0], p[1], p[2], p[3], 1, 1]; }
    readonly property var curveStandard: _curve("standard", [0.2, 0, 0, 1])
    readonly property var curveEmphasized: _curve("emphasized", [0.05, 0.7, 0.1, 1])
    readonly property var curveAccelerate: _curve("accelerate", [0.3, 0, 0.8, 0.15])
}
