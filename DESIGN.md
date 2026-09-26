# Lumen — Design System

> **Extremely capable underneath. Extremely simple on the surface.**
> 10× the functionality, 1× the visual complexity.

Status: **v0.2 — approved** (2026-09-25). The owner delegated open decisions; they're
resolved below and marked **✓**. Direction: *the depth and workflow of end-4's
illogical-impulse, in Lumen's calmer visual language* (see §13).
This document is the source of truth. If a config file disagrees with it, the config is wrong.

"Lumen" is a working name and can be renamed with one search-and-replace.

---

## 0. Principles

Every design decision is checked against these, in this order:

1. **Calm by default.** The idle desktop shows the wallpaper, your windows, and almost nothing else.
   Information appears when it's relevant and goes away when it isn't.
2. **One material, one voice.** All shell surfaces (island, bar, panels, launcher, notifications,
   OSD, lock screen) are built from the same tokens. Nothing is styled on its own.
3. **Motion explains.** Animations show where something came from, where it went, or that
   something changed. If an animation explains nothing, remove it.
4. **Keyboard first, pointer fine.** Every surface opens, works, and closes from the keyboard.
   Pointer targets are still at least 32 px.
5. **Fast is a feature.** Event-driven, not polling. Blur is used only where it helps you tell
   surfaces apart. A slow effect is a broken effect.
6. **Stable identity.** The wallpaper can suggest an accent color. It never changes the palette,
   the contrast, or the structure.

---

## 1. Visual identity

**Instrument glass.** Think of a precise instrument panel behind a pane of smoked glass:
dark graphite neutrals with a slight cool tint, one saturated **signal** accent used sparingly,
hairline edges instead of heavy borders, and depth that comes from light and blur rather than
from outlines.

What makes it recognizable (and different from macOS or Material):

| Trait | Lumen | Not |
|---|---|---|
| Neutrals | Cool graphite with a trace of blue (hue 255, chroma ≈ 0.01) | Pure grey, or saturated navy |
| Accent | **One** signal color, on ≤ 5 % of the pixels on screen | Accent-tinted everything (Material You) |
| Edges | 1 px inner hairline highlight (white at 8 %) on glass | Thick or colored borders |
| Depth | Blur + tint + one soft shadow | Drop shadows stacked on each surface |
| Shape | Continuous "squircle-ish" radii from a strict scale | Random per-widget radii |
| Numbers | Tabular figures everywhere (clock, %, time remaining) | Numbers that jitter as they change |
| Status | Small dots and tiny glyphs; color only for state | Colored icon soup |

Guidance on how much accent to use: accent marks *the active thing* (focused window border,
active workspace, a toggle that's on, progress fill, the text cursor). It is never used for
decoration.

---

## 2. Color system

Colors are defined in **OKLCH** (perceptually uniform, so themes stay consistent). Hex values are
derived from them. The contrast numbers below were measured against `surface` (WCAG 2.1).

### 2.1 Semantic roles (Dark, the reference theme)

| Token | OKLCH | Hex | Contrast on surface | Use |
|---|---|---|---|---|
| `bg` | 0.170 0.010 255 | `#0d1014` | — | Solid background, lock-screen dim, fallback when blur is off |
| `surface` | 0.215 0.011 255 | `#161a1f` | — | Base of glass panels (used with alpha, see §6) |
| `surface-elevated` | 0.255 0.012 255 | `#1f2329` | — | Cards inside panels, popovers, the launcher input |
| `surface-hover` | 0.300 0.012 255 | `#2a2e34` | — | Hover or keyboard-selected row |
| `text` | 0.960 0.004 255 | `#f0f2f4` | 15.6 : 1 | Primary text |
| `text-secondary` | 0.780 0.010 255 | `#b3b8be` | 8.8 : 1 | Supporting text, values |
| `text-muted` | 0.625 0.012 255 | `#83888f` | 4.9 : 1 | Captions, timestamps, disabled labels |
| `border` | white @ 8 % | `#ffffff14` | — | Hairline on glass, dividers |
| `border-strong` | white @ 14 % | `#ffffff24` | — | Focus ring base, input outline |
| `accent` | 0.800 0.115 212 | `#52d1e9` | 9.7 : 1 | Ion, see §2.2 |
| `accent-hover` | 0.850 0.115 212 | `#64e2f9` | — | Hover or pressed-in state |
| `on-accent` | 0.200 0.020 230 | `#0c181d` | 10.0 : 1 | Text or icons on an accent fill (never white on accent) |
| `success` | 0.800 0.140 152 | `#71d790` | 9.8 : 1 | Connected, charging, done |
| `warning` | 0.850 0.130 88 | `#f1c961` | 11.0 : 1 | Low battery, degraded |
| `error` | 0.700 0.170 25 | `#f66d67` | 6.1 : 1 | Failure, critical, recording dot |

Rule: `success`, `warning` and `error` are **state colors**. They show up as a dot, a glyph or a
thin fill, never as a whole panel background.

### 2.2 Accent ✓ Ion (default), all four selectable with `lumen accent <name>`

All four candidates share the same lightness and chroma, so they are equally legible and can be
swapped without touching anything else.

| Name | Hex | Character |
|---|---|---|
| **Ion** (proposed) | `#52d1e9` | Cool cyan-blue. Technical, futuristic, and at home with graphite. |
| Ember | `#f9aa60` | Warm amber like an instrument backlight. Very distinctive, but sits close to `warning`. |
| Iris | `#a39ef9` | Soft violet. Elegant, but common in rices (Catppuccin-adjacent). |
| Jade | `#5ed8a9` | Mint green. Fresh, but sits close to `success`. |

### 2.3 Themes

Themes change **only** the neutral ramp (plus accent lightness on Light). Roles, contrast targets
and structure stay the same.

| Theme | bg | surface | elevated | text | Notes |
|---|---|---|---|---|---|
| **Dark** | `#0d1014` | `#161a1f` | `#1f2329` | `#f0f2f4` | Reference theme |
| **Midnight** | `#060b18` | `#0d1424` | `#161e2f` | `#eff2f7` | Same lightness, chroma 0.03 toward blue |
| **OLED** | `#000000` | `#060709` | `#0d1013` | `#f0f2f4` | True black. Glass alpha goes up (less see-through) |
| **Light** | `#eef0f3` | `#f9fafc` | `#ffffff` | `#12161b` | text-secondary `#494d54`, muted `#6a6f76`; accent Ion becomes `#0077a1` (4.8 : 1), white on accent |

### 2.4 Wallpaper-derived accent (✓ available via `lumen accent wallpaper`, ii-style)

When turned on, the wallpaper script samples the dominant hue, **keeps L and C fixed** at the
accent values above, and replaces only the accent hue H. Hues that land within ±25° of the
success, warning or error hues are pushed away so a state color is never mistaken for the accent.
The rest of the palette stays the same. This replaces matugen's "paint everything" approach for
this desktop only; your current ii setup is not touched.

---

## 3. Typography

| Role | Family | Size / line height | Weight | Notes |
|---|---|---|---|---|
| `display` | UI | 136 / 1.0 | wght 380, ROND 100 | Lock-screen clock only |
| `title` | UI | 20 / 1.25 | 600 | Panel titles, island expanded title |
| `heading` | UI | 15 / 1.3 | 600 | Section headers, notification title |
| `body` | UI | 13 / 1.45 | 400 | Default |
| `body-strong` | UI | 13 / 1.45 | 500 | Toggle labels, bar clock |
| `caption` | UI | 11 / 1.35 | 500 | Timestamps, secondary values; letter-spacing +0.2 px |
| `mono` | Mono | 12.5 / 1.5 | 400 | Terminal, code, clipboard previews |
| `data` | UI with `tnum` | same as context | 500 | Anything numeric that changes |

- **UI font: Google Sans Flex** ✓ (changed 2026-09-26: already installed, so no manual download; its variable axes, including ROND for roundness, give the island clock a voice). Previously proposed: **Inter**. It's in the official Fedora repos as `rsms-inter-fonts`, has
  tabular figures (`tnum`), `cv11` (single-storey a) and `ss01` (open digits), and was built for
  UI sizes. ✓ Inter: official Fedora repo, no manual downloads.
- **Mono: JetBrainsMono Nerd Font.** Already installed. Nerd glyphs are used **only** inside the
  terminal and prompt. Shell UI icons come from a real icon set (see §9).
- Two families total. Hierarchy comes from size and weight, never from a third typeface.
- Sizes are in logical px and scale with the monitor scale factor.

---

## 4. Spacing

A 4 px base grid. Only these values are allowed:

| Token | px | Typical use |
|---|---|---|
| `space-1` | 4 | Icon to label |
| `space-2` | 8 | Inside compact controls |
| `space-3` | 12 | Between rows in a list |
| `space-4` | 16 | Panel padding (compact), gap between cards |
| `space-5` | 20 | Panel padding (standard) |
| `space-6` | 24 | Between panel sections |
| `space-8` | 32 | Large surfaces (launcher, lock screen) |

Hyprland mapping: `gaps_in = 4` and `gaps_out = 8` (screen edges), so tiled windows sit on the
same grid as the shell. Floating shell surfaces keep `space-2` (8 px) from screen edges.

---

## 5. Geometry

### 5.1 Radius scale

| Token | px | Used by |
|---|---|---|
| `radius-xs` | 6 | Checkboxes, tiny chips, progress track ends |
| `radius-sm` | 10 | Buttons, inputs, list-row highlight |
| `radius-md` | 12 | Cards inside panels, notification cards, **windows** |
| `radius-lg` | 20 | Panels: control center, launcher, notification center |
| `radius-full` | height / 2 | Island, bar pills, toggles, sliders |

**Nesting rule:** inner radius = outer radius − padding (at least `radius-xs`). A card with
`radius-md` (12) inside a `radius-lg` (20) panel with 8 px padding lines up exactly: 20 − 8 = 12.
This single rule prevents most "random rounded corner" problems.

### 5.2 Sizes

| Element | Size |
|---|---|
| Bar / island idle height | 32 px |
| Island idle width | 120–160 px (content-driven, see §8) |
| Island max expanded | 420 × 96 px (media: 420 × 132) |
| Control center | 360 px wide, height from content |
| Launcher | 600 px wide, 8 rows visible |
| Notification card | 360 px wide |
| Window border | 2 px, `radius-md` |
| Hit target min | 32 px (bar), 40 px (panels) |

---

## 6. Glass, blur, and elevation

### 6.1 Layers

```
L0  wallpaper                     — untouched
L1  windows                       — opaque by default (terminal is the one exception)
L2  shell chrome (bar pills, island)          — glass
L3  panels (control center, launcher, notif)  — glass, stronger
L4  focused control / popover inside a panel  — solid surface-elevated, no blur
```

The rule: **floating shell surfaces and "glass apps" are glass.** Glass apps are tools you glance
through: terminal (0.88), file manager, settings, mixers, system monitor (0.90 active / 0.82
inactive). Content apps (browser, video, games, editors, office) stay opaque, and anything
fullscreen is forced opaque. Context menus and the scratchpad backdrop are frosted too. Glass never goes on top of glass: inside a panel, cards are solid
`surface-elevated`.

### 6.2 Recipe

| Token | Tint (surface @ alpha) | Blur | Shadow | Edge |
|---|---|---|---|---|
| `glass-chrome` (L2) | surface @ 0.72 | medium | `shadow-sm` | inner hairline `border` |
| `glass-panel` (L3) | surface @ 0.80 | medium | `shadow-md` | inner hairline `border` |
| `glass-oled` | surface @ 0.90 | medium | none | inner hairline `border` |
| `solid-card` (L4) | surface-elevated @ 1.0 | none | none | none |

Blur values (in Hyprland, blur applies to the layer via `layerrule blur`, so all glass shares
one compositor setting):

| Token | Hyprland | Notes |
|---|---|---|
| `blur-medium` | `size = 6`, `passes = 3`, `noise = 0.012`, `contrast = 1.0`, `brightness = 0.85`, `vibrancy = 0.15` | The one blur for the whole desktop. |
| `blur-off` | — | ✓ Automatic in battery-saver mode (Phase 7) |

Hyprland has one global blur setting, so a separate `blur-small` or `blur-large` would only be
fake variation. Differences in strength come from the **tint alpha**, which costs nothing.
Readability is guaranteed by the tint: text contrast is computed as if the blur were fully
transparent over pure white or pure black, and it still passes AA at the alphas above.

### 6.3 Shadows

| Token | Value | Use |
|---|---|---|
| `shadow-sm` | 0 2 8 rgba(0,0,0,.28) | Bar pills, island idle |
| `shadow-md` | 0 8 32 rgba(0,0,0,.36) | Panels, island expanded |
| window shadow | Hyprland `range = 20`, `render_power = 3`, color #00000055, focused only | Floating windows only |

Tiled windows get **no shadow** (they don't float, so they shouldn't look like they do).

---

## 7. Motion

### 7.1 Categories

| Token | Duration | Curve | Use |
|---|---|---|---|
| `motion-micro` | 120 ms | `standard` | Hover, press, toggle knob, focus ring |
| `motion-normal` | 220 ms | `standard` | Panel open/close, notification in, list reflow |
| `motion-large` | 320 ms | `emphasized` | Workspace switch, launcher open, island morph |
| `motion-emphasis` | spring k=320 d=26 | spring | Island expanding for an event; nothing else |
| `motion-exit` | 0.7 × enter | `accelerate` | Every dismissal. Exits are always faster than entries |

Curves (cubic-bezier):

```
standard     0.20, 0.00, 0.00, 1.00   ease-out, crisp arrival
emphasized   0.05, 0.70, 0.10, 1.00   fast start, long settle (reads as "physical")
accelerate   0.30, 0.00, 0.80, 0.15   for exits
overshoot    0.34, 1.36, 0.64, 1.00   Hyprland-only approximation of the spring (≈4 % overshoot)
```

### 7.2 Rules

- **Nothing longer than 320 ms**, except the spring settling (still visually done by 350 ms).
- Only **transform and opacity** animate. Never width/height on large surfaces. The island is the
  single exception: its size morph *is* the message.
- Direction means something: workspaces slide horizontally in the direction you moved; panels
  grow from the element that opened them; notifications come from and leave toward the top-right.
- Fade distances are small: panels rise 8 px and scale from 0.96, never from 0.
- Windows: open = pop-in from 92 %, close = fade + 96 %, move/resize = `emphasized` 280 ms.
  Windows feel physical without bouncing.
- `prefers-reduced-motion` equivalent: one `motion.reduced = true` token that sets all durations
  to 0 except opacity (which drops to 100 ms).

---

## 8. The Island

The island is the **single place where the system talks to you.** It replaces OSDs, toasts,
and the bar's center.

### 8.1 Anatomy

```
idle          ╭──────────────────╮
              │  ●   14:32       │      120–160 × 32, glass-chrome
              ╰──────────────────╯
                 ↑ status dot (only when something needs you: recording, mic in use, DND)

idle +        ╭──────────────────╮
music         │ ▁▃▇▅▂ 14:32 ▂▅▇▃▁ │      live equalizer in the background, clock on top
              ╰──────────────────╯

compact       ╭─────────────────────────────╮
(event)       │ ▣  Song title — Artist  ıl│ │  ≤ 360 × 32, a few seconds, then back to idle
              ╰─────────────────────────────╯

expanded      ╭─────────────────────────────────────────╮
(event)       │  ▣▣   Title                             │  ≤ 420 × 96/132, glass-panel
              │  ▣▣   Supporting line                    │  auto-collapses
              │       ━━━━━━━━━━━━━━━━━━━━━━░░░░░  1:42 │
              ╰─────────────────────────────────────────╯
```

Three sizes only: **idle → compact → expanded.** Every state below maps to one of them.

### 8.2 States & priority

The island is its own layer-shell window per monitor (`lumen-island`, Overlay layer). Events show
only on the focused monitor; other monitors show the clock. Over a fullscreen app, idle and
ambient states disappear entirely and only real events come through.

**Persistent** (shown while true): critical battery (≤ 5 %, on battery) > recording > idle.

**Transient** (lower number wins; user feedback beats ambient info):

| # | State | Size | Content | Lifetime |
|---|---|---|---|---|
| 1 | OSD: volume, brightness, mic | compact | glyph, inline bar, value (device name after an output change) | 1.2 s after the last change, bursts update in place |
| 2 | Notification | expanded | app, title, one-line preview | 4 s |
| 3 | System event (Bluetooth, Wi-Fi, USB, charger, low battery, recording saved) | compact | glyph, title, muted detail | 2 s |
| 4 | Screenshot | compact | thumbnail, "Screenshot copied" (click opens it) | 2.5 s |
| 5 | Now playing (track starts or changes) | compact | art, title, small equalizer | 4 s |
| 6 | Workspace switch | compact | name or number | 0.8 s, 150 ms debounce |

- A preempted event is re-queued if it's worth replaying (notification, system, screenshot).
  Queued events go stale after their duration + 4 s. OSD and workspace events are never queued.
- **Music never takes over the island.** A track announces itself briefly, then the clock
  returns with a **live audio equalizer in the island's background** (cava, ~1 % CPU, running only
  while music plays and the idle island is visible).
- The shell ignores state "changes" for the first 2 s after startup (services settling).

### 8.2.1 Interaction

| Input | Result |
|---|---|
| Hover ≥ 300 ms | Peek: date, time and battery estimate, or the full player if media exists |
| Pointer leaves (after 250 ms) | Collapse |
| Left click | Act on what's shown (stop recording, open screenshot…) or pin open |
| Middle click | Play/pause |
| Right click | Dismiss the current event |
| Scroll / Shift + scroll | Volume / brightness |
| `Super + M` | Pin open with keyboard: Space play/pause, ←/→ previous/next, Esc close |
| Unpin | Esc, click again, focus moves to a window, or 6 s with the pointer away |

Pointing at the island pauses an event's timer. Brightness keys go through the shell
(`qs ipc call brightness up|down`) so user changes show in the island and hypridle's dimming
stays silent.

### 8.3 Motion

Size morph uses `motion-emphasis` (spring). Content crossfades at `motion-micro`, and new content
fades in only after the shape is 60 % of the way there, so text never squashes.
Collapse uses `motion-exit`.

---

## 8b. Overview & launcher

One overlay (`lumen-overview`) does both jobs. It opens over a frosted scrim: the scrim is `bg` at 50 %,
and Hyprland's layer blur frosts the desktop behind it.

```
          ╭──────────────────────────────────────────────╮
          │ ⌕  Search apps, windows and actions · = > ?  │   search pill (600 × 48)
          ╰──────────────────────────────────────────────╯
               ▣  ▣  ▣  ▣  ▣            recent apps (frecency)
   ╭──────────╮ ╭──────────╮ ╭──────────╮
   │ ▭▭  ▭    │ │   ▭      │ │    +     │   workspaces in use + current + "New"
   │ 1        │ │ 2        │ │ New      │   live window previews; drag a window to move it
   ╰──────────╯ ╰──────────╯ ╰──────────╯
```

Typing swaps the grid for a result panel with at most 8 rows. Results come in this order:
calculator (qalc: units, %, functions), apps (fuzzy + frecency, weak matches dropped), open windows,
actions (lock, suspend, log out, restart, shut down, capture, theme, accent), then web search.
Prefixes: `>` runs a command, `?` is web search only. Destructive actions need Enter twice within 3 s.

| Key | Action |
|---|---|
| tap Super · Super+Space · Super+Tab | Open (search) |
| Super+V / Super+. | Clipboard history / emoji |
| ↑↓ · Tab · Ctrl+N/P | Select |
| ↵ | Open or run; with an empty query, go to the selected workspace (←→) |
| Esc | Clear the query, then leave the mode, then close |
| Shift+Del | Remove a clipboard entry |
| Click / middle-click / drag a window preview | Focus / close / move to another workspace |

Live previews use screencopy and exist only while the overlay is open.

## 9. Iconography

- **One icon set, used as outlines:** Phosphor or Lucide, rendered at 16 / 20 px with a 1.5 px
  stroke, colored `text` or `text-secondary`. ✓ **Material Symbols Rounded** (variable font,
  what ii uses; one font file, so icon weight can follow text weight). It stays in the shell
  UI only and doesn't count against the two-typeface rule.
- An icon only gets the accent color when it shows an *active* state (toggle on).
- App icons (launcher, notifications) come from the system icon theme: **Papirus-Dark**
  (Fedora repo: `papirus-icon-theme`) so GTK/Qt apps match.
- Cursor: ✓ **Breeze** (already installed with Plasma, so it matches KDE apps), size 24.

---

## 10. Component architecture

### 10.1 Rendering stack ✓ Quickshell (same engine as ii)

The requirements (a morphing island, spring motion, one design system across the bar, panels,
launcher and notifications) go beyond what **Waybar + Rofi + SwayNC** can do *together*. Each of
them has its own CSS subset, its own window, its own animation model, and none of them can morph
shape. The result would be three products sharing a color file.

**Proposal: Quickshell for all shell UI.** It's already installed on your system
(`quickshell-git 0.2.1`), is QML with GPU rendering and real springs, and uses native Wayland
layer-shell. It has built-in, event-driven services for Hyprland IPC, PipeWire, MPRIS,
notifications (it *is* the notification daemon), UPower, Bluetooth, NetworkManager and system tray,
so almost nothing needs to poll a shell script. One process, one token file, one animation engine.

| Concern | Quickshell plan | Traditional plan (spec as written) |
|---|---|---|
| Bar | QML pills | Waybar |
| Island | QML (native morph + spring) | Only possible with a separate tool anyway |
| Launcher | QML | Rofi |
| Notifications | QML (built-in server) | SwayNC |
| Control center | QML | SwayNC panel / custom |
| OSD | Island | SwayOSD / scripts |
| Tokens | One `Theme.qml` generated from `theme/*.toml` | Duplicated into 3 CSS dialects |
| Idle cost | One process, event-driven | 3–4 processes plus polling scripts |

Hyprland-native parts stay native: hypridle, hyprlock (fallback lock),
kitty and fish.

### 10.2 Token pipeline

```
theme/
├── tokens.toml          ← the ONLY place values are written (colors, type, space, radius, motion, glass)
├── themes/
│   ├── dark.toml        ← neutral ramp overrides
│   ├── midnight.toml
│   ├── oled.toml
│   └── light.toml
└── build.py             ← small, readable, stdlib-only generator (no network, no deps)
        │
        ├─► generated/tokens.json        (read live by shell/theme/Theme.qml; recolours without restart)
        ├─► generated/hypr-theme.conf    (colors, gaps, rounding, blur, animations)
        ├─► generated/hyprlock-theme.conf
        ├─► generated/kitty-theme.conf
        ├─► generated/fish-theme.fish
        ├─► generated/gtk.css            (libadwaita/GTK4 + GTK3 accent & surface overrides)
        └─► generated/kvantum.kvconfig   (Qt)
```

Switching themes means running `lumen theme midnight`, which regenerates the files and hot-reloads
Hyprland and Quickshell (and kitty through remote control). Generated files are never edited by hand.

### 10.3 Repository layout

```
~/Projects/lumen/
├── DESIGN.md
├── theme/                 tokens + generator (above)
├── hypr/
│   ├── hyprland.conf      entry: sources everything below, nothing else
│   ├── monitors.conf
│   ├── environment.conf   hybrid GPU env (see §11)
│   ├── startup.conf
│   ├── look.conf          general/decoration/blur (reads generated tokens)
│   ├── animations.conf
│   ├── input.conf
│   ├── keybinds.conf
│   ├── rules.conf         window + layer rules
│   ├── workspaces.conf
│   └── hyprlock.conf       (hypridle.conf is generated, §22)
├── shell/                 Quickshell config (qs -c lumen)
│   ├── shell.qml
│   ├── theme/             Theme.qml (watches generated/tokens.json)
│   ├── components/        GlassSurface, LText, LIcon, HoverTarget … (primitives)
│   ├── services/          Audio, Brightness, Media, Network, Bluetooth, Power, Notifs, Sysinfo
│   └── modules/           Island, Bar, ControlCenter, Launcher, NotificationCenter, PowerMenu
├── kitty/  fish/  gtk/  qt/
├── scripts/               POSIX sh, only where there's no native service (screenshot, record, wallpaper)
└── install/               install.sh (symlinks only, dry-run by default), packages.md (every dependency explained)
```

Components depend only on `theme/` and `components/`. Modules depend on components and services.
Services never import UI. That keeps every widget restylable from tokens alone.

### 10.4 Adaptive bar (pills ⇄ one bar)

| Workspace | Bar | Island |
|---|---|---|
| Empty | Three floating glass pills with air between them | Glass pill |
| Has any window | The island **stretches out** into one long floating bar spanning pill-edge to pill-edge (same position, same rounded ends); the pills drop their own glass | Flat clock inside the bar; events get their own glass |

Emptying the workspace runs it backwards: the bar shrinks back into the island. Windows start
at `edgeGap + barHeight + gaps_out` in both modes, so nothing reflows. (A flush full-width edge
strip was tried and rejected: it read as a plain status bar.)

### 10.5 Island ⇄ overview hand-off

Opening the overview (tap Super / Super+Space) doesn't pop a new panel up. The search field
starts at the island's exact width and position and springs out to full width (island spring),
its text fading in once the shape is mostly open. Closing reverses it; the island takes its shape
back only once the field is island-sized again (`Overview.handoff`). The island and the search
are one object.

---

## 11. Coexistence & hardware constraints

- **Your current end-4/ii setup and KDE Plasma stay intact.** Lumen lives in `~/Projects/lumen`
  and runs as a separate config (`Hyprland -c …` or a user-level session entry). Nothing in
  `~/.config/hypr`, `~/.config/quickshell/ii` or the matugen pipeline gets overwritten until you
  explicitly choose to switch. ✓ `bin/lumen-session`: nested in a window for testing, or from
  a TTY / session entry for real use.
- **Hybrid GPU (AMD HawkPoint2 iGPU + RTX 3050 Mobile):** the compositor renders on the AMD iGPU
  (`AQ_DRM_DEVICES` pointing at the AMD card first, via stable `/dev/dri/by-path` symlinks).
  NVIDIA is used only on demand (`prime-run` / `switcherooctl`). No global
  `__GLX_VENDOR_LIBRARY_NAME=nvidia` or `GBM_BACKEND=nvidia-drm`, so dGPU-off and battery life keep
  working.
- **Config format:** ✓ classic `.conf` (hyprlang). Verified on 0.56.2 with `--verify-config`;
  rules use the ≥ 0.53 syntax (`windowrule = float on, match:class …`).
- **GPU selection:** `lumen-session` finds the cards by PCI vendor ID at login (card numbers change
  between boots). The HDMI port is wired to the NVIDIA card, so it's included second when
  its driver is loaded. `LUMEN_DGPU=off` excludes it.

---

## 12. Quality checklist (applied to every component)

- [ ] Only tokens, no raw values (checked by grepping for `#` hex values and bare numbers outside `theme/`)
- [ ] Aligned to the 4 px grid; radii follow the nesting rule
- [ ] Text meets AA contrast on its real background
- [ ] Works completely from the keyboard; visible focus ring; Esc closes
- [ ] Enter and exit motion from §7, and a reduced-motion variant
- [ ] Idle CPU ≈ 0 %; no timer faster than 1 s (except while the surface is visible)
- [ ] Failure states: service missing, no battery, no player, no network. The UI hides the
      element rather than showing an error
- [ ] Works under the Dark, OLED and Light themes

---

## 13. ii parity map

What makes illogical-impulse feel good, and where each feature lives in Lumen. The *capability*
is kept; the *presentation* follows this document.

| ii feature | Lumen equivalent | Phase | Key (same as ii) |
|---|---|---|---|
| Top bar | Floating pills: workspaces · island · status | 3 | — |
| OSD (volume/brightness) | Island compact state | 4 | hardware keys |
| Media controls popup | Island expanded (media) | 4 | Super+M |
| Overview (workspace grid + live window previews + search) | Overview: the launcher *is* the search field on top of the grid | 5 | tap Super / Super+Tab |
| Clipboard / emoji in overview | Launcher modes | 5 | Super+V / Super+. |
| Notification popups | Island (single) + stacked cards (burst) | 6 | — |
| Right sidebar (toggles, notifications, calendar) | Control Center ✓ (v2: Wi-Fi/Bluetooth wide tiles + a 4-column grid of round toggles and actions: Focus, Caffeine, Night light, Mic, Airplane, Power mode, Game mode, Dark/Light, Keyboard light, WARP and VPN when present, Record, Screenshot, Pick colour; now-playing card tinted by the album): Wi-Fi/Bluetooth/output lists, DND, night light, mic, power mode (saver ⇒ blur off), VPN (if configured), volume/brightness sliders, system stats (sampled only while open), notification history | 7 | Super+N |
| Left sidebar (AI chat, translator) | Assistant panel (optional module, off by default) | 10 | Super+A |
| Session screen | Power menu ✓: Lock · Sleep act at once; Log out · Restart · Shut down ask once more | 7 | Super+Escape, Ctrl+Alt+Del |
| Cheatsheet | ✓ Keyboard & gestures sheet generated from keybinds.conf by build.py (sections, readable names, 1…0 and arrow rows folded); type to filter | 8 | Super+/ |
| Wallpaper selector | ✓ Frosted picker: categories (~/Pictures/Wallpapers sub-folders, Plasma packages, system), cached thumbnails, keyboard nav, Shuffle, **Match accent** (OKLCH hue of the wallpaper's most vivid colour, kept clear of state hues). The shell draws and cross-fades the wallpaper | 8 | Ctrl+Super+T · Ctrl+Super+Alt+T random |
| Screen corners / region tools | Screenshot/record/OCR region selector | 8 | Super+Shift+S/R/T |
| Lock screen | Quickshell ext-session-lock ✓: hero clock, frosted widget cards (media · battery ring · calendar · notification count, never content), avatar + password pill, **Face ID** (Gaze; ring around the avatar), **macOS-style transitions** (desktop snapshot blurs into the lock; on unlock it sharpens back before the lock releases). hyprlock remains the no-shell fallback | 8 | Super+L |
| Material You everything | **Not copied.** A stable palette, with an optional wallpaper *hue* (§2.4) | — | — |

## 14. Terminal & prompt (Lumen sessions only)

`bin/lumen-session` exports `KITTY_CONFIG_DIRECTORY=lumen/kitty` and `STARSHIP_CONFIG=generated/starship.toml`,
so the same binaries look like ii elsewhere and like Lumen here.

- **kitty**: includes the shared `~/.config/kitty/kitty.conf` (fonts, keymaps, kittens), then the generated
  theme: 16 ANSI colours at one OKLCH lightness/chroma (no colour shouts), bg/fg/cursor/selection/tabs
  from roles, and its own background opacity (so text stays crisp; Hyprland leaves kitty at 1.0). A
  gliding cursor trail and 12/14 px padding. `lumen theme …` reloads running kitties (SIGUSR1).
- **Starship**: one line, information only when it matters: path (accent), branch and status, language
  version only inside projects, duration over 2 s, and ❯ in accent (error red after a failed command).

## 15. Lumen Settings (Super+I)

A separate Quickshell process (`shell/settings.qml`): crash-isolated, no memory while closed. The main
shell only launches or focuses it (`SettingsSources`, `SettingsState.launch`, one per Hyprland session via a
pid file). 14 pages with search (Ctrl+F; matches names and keywords): Appearance (theme previews, accent,
transparency, reduced motion, 12/24 h, app icon theme, UI sounds), Wallpaper, Bar & Island, **Windows** (gaps,
corners, focus border, animation speed, focus follows pointer; applied live), **Notifications** (Focus,
banners, sound, per-app mute, clear history), **Network** (Wi-Fi join, airplane, VPN, WARP), **Bluetooth**
(connect, battery, pair), Sound, Display, **Lock screen** (widget toggles), Face ID (status, looks, test,
**calibrate**, **anti-photo check on/off and strictness**, diagnostics), Power, Keyboard & Gestures, About.

The settings app is a *client*: it never creates the notification server (`LUMEN_SETTINGS_APP=1`). It mirrors
state files and sends changes to this session's shell through `bin/lumen-shell-ipc`, which picks the shell
by `HYPRLAND_INSTANCE_SIGNATURE` so parallel sessions never cross. Root-level Face ID changes go through
`scripts/gaze-admin.sh` (pkexec, password every time; `[liveness]` keys and one diagnostics drop-in only;
validated; a one-time backup of the original).

Where preferences live:
- design-level (theme, accent, transparency, clock, motion) → `~/.local/state/lumen/state.json` via
  `bin/lumen` → `theme/build.py` → `generated/*`. Writes are serialised (flock, unique temp, atomic mv)
  because several processes may write at once.
- shell-only (island date, workspace announcements, hot corners, night light) → `shell.json` (Persist),
  watched by every Lumen process.

## 16. Face ID (lock screen only)

Gaze (`pam.d/hyprlock-gaze`), run as a second, independent PAM conversation next to the password one.
The camera starts on intent (a key or pointer movement, or waking from sleep), never within 2.5 s of a manual
lock, and at most once per 2.5 s. A miss hands over to the password silently and is never counted as a
password failure. Unlock happens only on PamResult.Success. Never used for sudo, polkit or login.

## 17. Hyprland config is Lua ✓ (ported 2026-09-26)

Hyprland 0.57 removes the hyprlang `.conf` format, so Lumen's config is Lua: `hypr/hyprland.lua` loads the
generated tokens (`generated/hypr/tokens.lua`, as `LM`) and requires `environment`, `monitors`, `input`,
`look`, `animations`, `workspaces`, `rules`, `keybinds` and `startup`. Machine-local overrides go in
`~/.config/lumen/local.lua`. hyprlock keeps its hyprlang file; hypridle's is generated (§22).

At runtime a dispatch is a Lua expression (`hl.dsp.focus({ workspace = 3 })`). The shell builds every
one in **`services/Hypr.qml`**, the only place with dispatch syntax. Runtime config changes (game mode,
battery-saver blur) use `hyprctl eval 'hl.config({ … })'`. Every bind carries a `"Section: Label"`
description, and the cheatsheet reads those live from `hyprctl binds -j`.
Check the config: `Hyprland --verify-config -c hypr/hyprland.lua`.

## 18. The bar's app menu

When the bar is merged (windows are open), the focused app's icon, name and window title sit right of
the workspaces, like a menu bar. Click it or press **Super+Alt+Enter** for a frosted menu of window
actions: New window, Float, Maximise, Fullscreen, Keep on all workspaces, Move to (workspaces 1–5 and
the scratchpad), Screenshot this window, Close, Force quit (in red). Global app menus (File/Edit/…) are
not available to Wayland shells for most toolkits, so Lumen offers the window's actions instead.

## 19. Icons, sounds, mark

- **App icons**: Lumen can use its own icon theme (default McMojave-circle-dark) while KDE and ii keep
  theirs: `Apps.iconNamed` indexes the theme's app icons once (SVG first, then the largest PNG) and
  falls back to the system theme for anything missing. Settings → Appearance.
- **UI sounds** (`services/Sounds.qml`): notification, volume tick (throttled), screenshot, lock and
  unlock, device or charger in and out, battery low. Ocean first, freedesktop as the fallback, 40 %
  volume, silent during Focus and Game mode (except critical). Settings → Appearance.
- **Mark**: the island, glowing: a white pill with accent light radiating from behind it, on a dark
  squircle. `components/LumenLogo.qml` (follows the accent) and `assets/lumen.svg` (static).

## 20. Face ID power rule

On AC, Face ID starts on intent (a key, the pointer, or lid open). On battery the camera never starts by
itself: press **F2** on the lock screen. Diagnosis tool: Settings → Face ID → Details (Gaze's own
per-step scores).

## 21. Tray drawer

Background apps (Discord, Steam, WARP, KDE Connect…) get one quiet button in the status pill: up to three
of their icons overlapped and desaturated, with an accent dot when one wants attention. It opens the
**tray drawer**, a frosted list with every app's name and status line, in colour. Click opens the app,
right-click or ⋯ opens its own menu, and middle-click runs its secondary action. The drawer also opens with
a right-click on the workspaces pill or on the resting island, with **Super+Alt+T**, or with
`ipc call tray toggle`. The button hides when nothing is in the tray.

## 22. Idle, and why it checks the session

Settings → Power → When idle picks **Lock after** (2/5/10/30 min, never) and **Sleep after** (15/30/60
min, only on battery, never), stored as `idle_lock`/`idle_sleep` in state. `build.py` generates
`generated/hypr/hypridle.conf`: dim a minute before the lock, screen off 30 s after, then suspend no
sooner than a minute after the lock. `lumen set idle_*` restarts only this session's hypridle, never
another session's.

Every step runs through `scripts/idle.sh`, which does nothing unless this login session is the active
one (`loginctl show-session $XDG_SESSION_ID -p Active`). Without that check, a Lumen session left
running on another tty sees no input, decides you're away, and dims the backlight or suspends the whole
laptop while you work in KDE or ii. (That was the "random sleep" bug of 2026-09-26.)

## 23. Admin prompts (polkit) and toolkit consistency

**Polkit**: the shell is the session's authentication agent (`services/Polkit.qml`, Quickshell's
`PolkitAgent`), and `modules/polkit/PolkitPrompt.qml` draws the prompt. It's a frosted card over a
dimmed desktop with exclusive keyboard focus, showing what is asking, as whom (switchable if there are
several admins) and a password well. Enter authenticates and Esc cancels; clicks outside do nothing.
A wrong password gets a red edge, a shake and polkit's own message. "Details" shows the action id.
polkit checks the password itself (PAM `polkit-1`) and Lumen only passes it through, so Face ID is never
involved. The agent is not registered in the Settings app or in nested sessions. If registration fails,
the shell starts KDE's agent, so prompts are never left unanswered. Dev review without a real agent:
`ipc call polkit mock | mockFail | mockClose` (LUMEN_DEV only).

**GTK**: adw-gtk3-dark with color-scheme prefer-dark (already the user's global setting).
**Qt**: KDE's platform theme (Breeze) by default. If `qt6ct` is installed (`sudo dnf install qt6ct`,
official repo), lumen-session switches the Lumen session to it. `build.py` generates
`generated/qt6ct/` (a palette from the tokens, the Darkly style when installed, else Breeze, the shell's
icon theme, UI and mono fonts), and `~/.config/qt6ct/qt6ct.conf` is linked to it unless you already have
your own file there. KDE apps off Plasma pick Breeze Light through KColorSchemeManager (qt6ct reports no
dark colour scheme), so `build.py` also writes `generated/share/color-schemes/Lumen.colors` and per-app
`[UiSettings] ColorScheme=Lumen` defaults in `generated/xdg/`. The Lumen session appends those folders to
`XDG_DATA_DIRS` / `XDG_CONFIG_DIRS` *after* the user's own, so kdeglobals and Plasma are never touched and
a scheme picked inside an app still wins. The overview passes the same variables to apps it launches.
**Cursor**: GTK apps read it from gsettings, which is user-wide, so Lumen sets it at login and on
`lumen set cursor`.

## 24. Sharing a login with other desktops

The user's systemd and D-Bus are shared by every session (Lumen on tty3, ii on tty5, KDE).
- **Portals** need `graphical-session.target`, which only starts through another unit, so
  `lumen-session.target` (in `systemd/`, linked into `~/.config/systemd/user`) binds it. lumen-startup
  starts it unless another desktop already holds it. lumen-session stops it when Hyprland exits.
- **Notifications**: one owner per bus. If another shell owns `org.freedesktop.Notifications`, Lumen
  mirrors instead: it runs `busctl --user monitor` for Notify calls and shows them in the island and
  history, without live action buttons. The owner is re-checked every 10 s, and Lumen's own server
  takes over when the other one quits.
- **Idle**: see §22 (every step checks that its session is the active one).

## 25. Moving windows

Super+Shift+arrow moves a window within the layout. **Ctrl+Super+Shift+←/→** takes it to the
previous or next workspace, and you follow it. **Ctrl+Super+Shift+↑/↓** sends it to the monitor
above or below.

## 26. Sidebar tabs

**Controls tab**, top to bottom:
- a header with your picture (or initial) in an accent ring, a greeting for the time of day, the date and battery;
- Wi-Fi and Bluetooth tiles;
- four even rows of round toggles and actions: Focus, Caffeine, Night light, Mic, Airplane, Power mode,
  Game mode, Dark, Keys, WARP, Glass (transparency), Lock, Record, Screenshot, Copy text, Pick colour;
- volume and brightness sliders with live percentages;
- now playing and system stats;
- a month calendar with ‹ › to change month and the title to jump back; it resets whenever the sidebar opens.
Super+A opens Controls, Super+N opens Notifications, and the top-right corner opens Controls.

The sidebar has two tabs, **Controls** and **Notifications**, switched by a sliding pill. The
Notifications tab shows an unread count. The status pill opens Controls, or Notifications if you click
its unread dot. Super+N opens Notifications. Ctrl+Tab switches tabs, and the content slides and
cross-fades.
Notifications are grouped into one card per app: a header with the icon, name, count and newest time,
collapse, and dismiss-all. A group with more than two collapses to the latest two, with stacked sheets
underneath and "Show N more". The toolbar has a Do Not Disturb pill and Clear all. With nothing left:
"You're all caught up" (or the Do Not Disturb note).

Bar popups (app menu, tray drawer) use the xdg-popup grab (`grabFocus`), not HyprlandFocusGrab. The
focus grab didn't know about the popup surface, so it swallowed clicks inside it.

## 27. Connectivity tiles: one control, one job

A tile used to toggle its radio on click and open its list from a small chevron; people opened
the tile to see networks and switched Wi-Fi off instead. Now the **round icon disc is the switch**
(filled with the accent when on) and **the rest of the tile opens the list**. Keyboard: Space
toggles, Enter or → opens. Lists group what matters (Wi-Fi: Connected · Saved · Other; Bluetooth:
My devices · Nearby) and keep secondary actions behind **⋯** so a click never disconnects by accident.

## 28. Devices in the island

Plugging something in is an event the island should explain, calmly. A device never seen before
gets a card with a **New** badge; drives and displays always get a card, because there is something
to do (Open · Eject, Arrange). Everything else, and every disconnect, is a one-line pill with the
device's real name and icon. Types come from USB interface classes, never from guessing names.

## 29. Lumen Halo

The assistant is a panel under the island, not a window: it belongs to the desktop. Its mark is a
**ring of light**; while it works, a slow gradient turns around the panel's edge and brightens
(motion explains that something is happening, with nothing bouncing). Rules:

- **Nothing is read until you turn it on; nothing is sent until you press Enter.** Context is a row
  of chips (Selection, Clipboard, Screen, Window, System, Project).
- **Skills are slash commands**, so the empty prompt stays calm and power is one `/` away.
- **Answers are for doing**: Copy, Insert into the app you came from, Save to notes, Retry; shell
  code blocks can run in a terminal only after a second press, and risky ones say so.
- **Local first**: with Ollama, "Automatic" answers with the smallest text model (it fits in video
  memory, so it's fast) and a vision model only when a screenshot is attached.
- Closing Halo never loses an answer: the island shows it thinking and says when it's ready.

