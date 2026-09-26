# Developing Lumen

## Run it in a window

```sh
~/.config/lumen/bin/lumen-session
```

Run this inside any Wayland desktop and Lumen opens nested in a window. Nested sessions:

- live-reload the shell when you save a file (`LUMEN_DEV=1`);
- never start session-wide services (portals, idle, the polkit agent);
- never run automations that change shared settings.

For screenshots from a script, create a headless output:

```sh
export HYPRLAND_INSTANCE_SIGNATURE=<the nested instance>
hyprctl output create headless LUMENTEST
grim -o LUMENTEST shot.png
```

## Useful hooks (only with `LUMEN_DEV=1`)

```sh
qs ipc --pid <pid> call notifyTest add "App" "Title" "Body"   # a local notification; never touches D-Bus
qs ipc --pid <pid> call polkit mock                           # preview the admin prompt
qs ipc --pid <pid> call aiTest mock                           # a streamed demo answer, no network
qs ipc --pid <pid> call plannerTest event "fri 7pm Concert"
qs ipc --pid <pid> call clipTest pins
LUMEN_SETTINGS_APP=1 qs -p ~/.config/lumen/shell/lock-preview.qml   # the lock screen in a window
```

## Conventions

- **Tokens only.** Take colours, sizes and durations from `Theme`, never literals.
- **Icons** are Material Symbols ligature names. Check a new one renders as a single glyph (for example with `hb-shape`).
- **Don't name a property `top`, `left`, `right` or `bottom`**: they clash with anchor lines.
- **Services never draw; modules never run commands.**
- **Root actions** go in a `scripts/*-admin.sh` helper with validated arguments, run through `pkexec`.
- **Keybinds** carry a `"Section: Label"` description. Run `scripts/gen-shortcuts.py` to refresh `docs/SHORTCUTS.md`.
- **Hyprland config:** check it with `Hyprland --verify-config -c hypr/hyprland.lua`.
- **Shell scripts:** check them with `shellcheck -S warning`.

See [CONTRIBUTING.md](../CONTRIBUTING.md) for pull requests.
