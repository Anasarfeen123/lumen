# Configuring Lumen

Almost everything is in **Settings** (<kbd>Super</kbd>+<kbd>I</kbd>). This page covers what's underneath: the `lumen` command, where your preferences live, and how to override things without editing Lumen's files.

## Settings

Sixteen pages, and the search box finds any setting by name or keyword ("gaps", "sunset", "charge"). Changes apply immediately to the shell, windows, terminal and lock screen, and they're saved when you make them.

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
lumen reload                               # reload Hyprland and the shell
lumen check                                # contrast report for the active theme
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
- the hypridle config.

To make your own theme, copy `theme/themes/dark.toml`, change the values, run `lumen theme <name>`, and use `lumen check` to see contrast ratios.

## Scratchpads and apps

- The **drop-down terminal** (<kbd>F12</kbd>) is kitty with the class `lumen-dropterm`.
- The **music scratchpad** (<kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd>) starts the app chosen in Settings → Sound: YouTube Music (as a web app of your browser) or Spotify.
- The default apps for Files, Browser, Code editor and Task manager are at the top of `hypr/keybinds.lua`. Each one picks the first program you have installed.
