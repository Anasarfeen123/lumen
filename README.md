# Lumen

A Hyprland desktop built as one product. See **DESIGN.md**; it's the source of truth.

## Try it (safe: nothing in ~/.config/hypr or your ii setup is touched)

```sh
ln -sfn ~/Projects/lumen ~/.config/lumen     # once
~/.config/lumen/bin/lumen-session            # inside your current session: opens nested in a window
```

Real session: press Ctrl+Alt+F3 and log in. `~/.bash_profile` starts Lumen automatically on tty3 (see the `lumen tty3` block; log in `~/.cache/lumen-session.log`).

## Layout

| Path | What |
|---|---|
| `theme/tokens.toml`, `theme/themes/*.toml` | Every design value. Edit here only. |
| `theme/build.py` | Generates `generated/` (stdlib Python, no network) |
| `hypr/` | Hyprland modules, hyprlock, hypridle |
| `shell/` | Quickshell UI: `theme/` tokens, `components/` primitives, `services/` (audio, battery, network, bluetooth), `modules/` (bar, island, overview) |
| `bin/lumen-session` | Starts Hyprland: GPU detection, nested test mode |
| `bin/lumen-startup` | Everything launched at login |
| `bin/lumen` | `lumen theme · accent · accent-hue · transparency · clock · motion · check` |
| `shell/settings.qml` | Lumen Settings: a separate app process (Super+I) |
| `bin/lumen-dgpu` | Run one app on the NVIDIA GPU |
| `scripts/` | screenshot, screen-record, wallpaper, emoji-data |

Machine-local overrides: `local.conf` (Hyprland), `session.env` (e.g. `LUMEN_DGPU=off`). Both untracked.
