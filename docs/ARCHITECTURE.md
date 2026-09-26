# How Lumen is built

Lumen is three layers that share one set of design tokens:

```
theme/tokens.toml ──► theme/build.py ──► generated/  (tokens.json, hypr/tokens.lua, hypridle.conf, kitty, qt6ct…)
                                            │
            ┌───────────────────────────────┼───────────────────────────────┐
            ▼                               ▼                               ▼
   Hyprland (hypr/*.lua)          Quickshell shell (shell/)            Scripts (scripts/, bin/)
   windows, rules, binds,         bar, island, sidebars, overview,     screenshots, OCR, recording,
   animations, gestures           lock, settings, AI, polkit agent     updates, root helpers
```

## Repository layout

| Path | What |
|---|---|
| `theme/` | `tokens.toml` (every design value), `themes/*.toml`, and `build.py` (standard-library Python) |
| `hypr/` | Hyprland config in **Lua**: `hyprland.lua` loads `environment`, `monitors`, `input`, `look`, `animations`, `workspaces`, `rules`, `keybinds` and `startup`. `hyprlock.conf` is the fallback lock. |
| `shell/` | The Quickshell UI. `shell.qml` is the desktop shell and `settings.qml` is the Settings app (a separate process). |
| `shell/theme/` | `Theme.qml`, which reads `generated/tokens.json` and updates live |
| `shell/components/` | Primitives: `GlassSurface`, `LText`, `LIcon`, `HoverTarget`, `LumenPopup`, `LField`, `Segmented`, `LSwitch`, `LSlider`… |
| `shell/services/` | About 50 singletons with no UI: Audio, Network, Bluetooth, Notifications, Island, Focus, Planner, Weather, Ai, Updates, Clipboard, Switcher, Sun… |
| `shell/modules/` | The UI: `bar`, `island`, `sidebar`, `planner`, `overview`, `switcher`, `lock`, `settings`, `ai`, `polkit`, `cheatsheet`, `session`, `wallpaper`, `corners`, `background` |
| `bin/` | `lumen` (preferences CLI), `lumen-session` (starts Hyprland, picks GPUs), `lumen-startup`, `lumen-shell-ipc`, `lumen-dgpu`, `lumen-launch` |
| `scripts/` | Screenshot, OCR, recording, wallpaper, updates, AI, idle, music, and the pkexec root helpers |
| `systemd/` | `lumen-session.target`, which starts the portals |

## Key ideas

- **One source of design truth.** Components never hard-code a colour or a duration; they read `Theme`. That's what lets the whole desktop re-theme instantly and stay consistent. See [DESIGN.md](../DESIGN.md).
- **Services own state; modules draw it.** A module never runs a command itself. It calls a service, such as `Audio.nudge()` or `Focus.set("work")`.
- **The island is a controller.** Anything can `Island.push({ kind, priority, duration, data })`, and `services/Island.qml` decides what shows. Lower priority numbers win, events with the same key update in place, and queued events go stale.
- **Settings is a separate process.** It never owns the notification server or the polkit agent. It edits preferences, which the shell watches, and calls the shell over IPC (`bin/lumen-shell-ipc`).
- **Only the real session's main shell automates.** Schedules, night light, wallpaper changes and update checks check `Persist.automates`, so test windows and Settings never act on shared state.
- **Several sessions can run at once.** For example, Lumen on one TTY and another desktop on another. Idle steps check that their session is the active one, IPC targets the caller's session only, and notifications fall back to mirroring when another program owns the notification service.

## Talking to the shell

Every shell feature has an IPC target, so scripts and keybinds can drive it:

```sh
~/.config/lumen/bin/lumen-shell-ipc sidebar controls       # or: notifications, detail wifi
~/.config/lumen/bin/lumen-shell-ipc timer start 25m
~/.config/lumen/bin/lumen-shell-ipc focus set work
~/.config/lumen/bin/lumen-shell-ipc updates check
~/.config/lumen/bin/lumen-shell-ipc island event bolt "Hello" "from a script"
```

`qs ipc --pid <pid> show` lists every target and function.
