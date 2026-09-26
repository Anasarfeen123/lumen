# Configuring Lumen

Almost everything is in **Settings** (<kbd>Super</kbd>+<kbd>I</kbd>). This page covers what's underneath: the `lumen` command, where your preferences live, and how to override things without editing Lumen's files.

## Settings

Twenty pages in five groups (Personalise, Connections, Devices, Focus & privacy, System), and the search box finds any setting by name or keyword ("gaps", "sunset", "charge"). Changes apply immediately to the shell, windows, terminal and lock screen, and they're saved when you make them.

**Settings → Advanced** opens Lumen's files (and creates `local.lua` / `session.env` from a template), runs a read-only health check (Hyprland config errors, theme contrast, the install link, missing programs, Ollama), opens the startup, shell and journal logs, and resets preferences by moving the file aside, never deleting it.

## The `lumen` command

`~/.config/lumen/bin/lumen` is what Settings uses underneath, so you can script anything it does.

```sh
lumen theme dark|midnight|oled|light      # colour theme
lumen accent ion|ember|iris|jade|wallpaper
lumen transparency on|off|toggle          # window glass (Super+Shift+G)
lumen clock 12h|24h
lumen motion full|reduced
lumen set gaps compact|normal|roomy
lumen set corners square|soft|round
lumen set border off|thin|normal
lumen set anim_speed fast|normal|relaxed
lumen set follow_mouse on|off
lumen set cursor Bibata-Modern-Classic|Bibata-Modern-Ice|Bibata-Modern-Amber|breeze_cursors
lumen set cursor_size 24|28|32
lumen set idle_lock 2|5|10|15|30|never     # minutes
lumen set idle_sleep 15|30|60|battery|never
lumen set accent_style exact|adaptive|subtle|mono
lumen set accent_intensity 50-130           # percent
lumen set glass_level 0-100                 # how frosted panels and windows are
lumen set motion_scale 50-200               # animation speed, percent
lumen reload                               # reload Hyprland and the shell
lumen rebuild                              # regenerate app themes (Qt/KDE, kitty…)
lumen check                                # contrast report for the active theme

# The island, from your own scripts
lumen progress "Backing up" 40             # 0-100, -1 (no estimate), done or fail
lumen run --title "Building" -- make -j8   # shows it working, then ✓ or ✗ with the time taken

# Workspace snapshots: which apps are open, where, and each terminal's folder
lumen snapshot save coding
lumen snapshot restore coding
lumen snapshot list | delete <name>
```

Values outside these lists are refused, so a typo can't break your config.

## Where things live

| Path | What |
|---|---|
| `~/.config/lumen` | A link to the folder you cloned (the code) |
| `~/.local/state/lumen/state.json` | Theme, accent, window and idle preferences |
| `~/.local/state/lumen/shell.json` | Shell preferences: widgets, Focus schedules, weather city, music app, AI provider… |
| `~/.local/state/lumen/planner.json`, `notes.md` | Your agenda, to-dos and notes |
| `~/.local/state/lumen/notifications.json` | Notification history |
| `~/.local/state/lumen/ai/` | Your AI API key, if you added one (mode 600) |
| `~/.local/state/lumen/clip-pins/` | Pinned clipboard images |
| `~/.local/state/lumen/snapshots/` | Saved workspace snapshots |
| `~/.face` | Your lock-screen picture |
| `~/Pictures/Wallpapers` | Wallpapers; sub-folders become categories in the picker |

`generated/` inside the repo is rebuilt from the tokens and your preferences. Don't edit it.

## Local overrides (untracked by git)

| File | Use |
|---|---|
| `local.lua` | Extra Hyprland config loaded last, for your monitors, keyboard layout or extra binds. It's plain Hyprland Lua (`hl.monitor{…}`, `hl.bind(…)`). |
| `session.env` | Environment for the session, e.g. `LUMEN_DGPU=off` to leave an NVIDIA GPU completely alone. |

Example `local.lua`:

```lua
hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@144", position = "auto-right", scale = 1 })
hl.config({ input = { kb_layout = "us,de", kb_options = "grp:alt_shift_toggle" } })
hl.bind("SUPER + B", hl.dsp.exec_cmd("firefox"), { description = "Apps: Firefox" })
```

A `description` of the form `"Section: Label"` also puts the bind in the cheatsheet and on the Keyboard settings page.

## Themes and design tokens

Every colour, size, radius, blur and animation curve comes from `theme/tokens.toml` and `theme/themes/*.toml`. Colours are written in OKLCH, so light and dark themes keep the same contrast. `theme/build.py` turns them into:

- Hyprland tokens (`generated/hypr/tokens.lua`);
- the shell's `tokens.json`;
- kitty, starship and qt6ct colours;
- the hypridle config;
- a KDE colour scheme (`generated/share/color-schemes/Lumen.colors`) and per-app defaults (`generated/xdg/`) so Dolphin, Kate, Okular and other KDE apps use Lumen's colours, the Darkly style and your icon theme. The Lumen session adds these folders to `XDG_DATA_DIRS` / `XDG_CONFIG_DIRS` *after* your own, so a scheme you pick inside an app still wins, and Plasma never sees them.

To make your own theme, copy `theme/themes/dark.toml`, change the values, run `lumen theme <name>`, and use `lumen check` to see contrast ratios.

## Scratchpads and apps

- The **drop-down terminal** (<kbd>F12</kbd>) is kitty with the class `lumen-dropterm`.
- The **music scratchpad** (<kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd>) starts the app chosen in Settings → Sound: YouTube Music (as a web app of your browser) or Spotify.
- The default apps for Files, Browser, Code editor and Task manager are at the top of `hypr/keybinds.lua`. Each one picks the first program you have installed (the browser prefers Brave Origin, then Brave, Firefox, Chromium).

## Lumen Halo

Settings → Halo chooses where answers come from:

- **This computer** (Ollama): nothing leaves your machine. With **Automatic** on, Halo answers with your smallest text model (it fits in video memory, so it's quick) and switches to a model that reads images only when you attach your screen. Settings → Halo downloads recommended models (Llama 3.2 3B, Gemma 3 4B, Qwen 2.5 Coder…) or any name from ollama.com/library, and removes them.
- **Claude**: your own Anthropic API key, stored in `~/.local/state/lumen/ai/` (mode 600).

`scripts/ai.sh` is Halo's only connection to a model; `scripts/halo-context.sh` reads context (system snapshot, focused window, project diff, clipboard) only for the chips you turn on.
