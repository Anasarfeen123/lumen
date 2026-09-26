# Contributing to Lumen

Thanks for helping. Lumen aims to be one coherent product, so a small, well-fitting change beats a big one.

## Before you start

- Read [DESIGN.md](DESIGN.md). It's the source of truth for how things look and behave.
- For anything bigger than a fix, open an issue first so we can agree on the shape.

## Working on it

- Run Lumen in a window with `bin/lumen-session` from any Wayland desktop. The shell live-reloads as you save. See [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md).
- Take colours, sizes and motion from `Theme` (the design tokens), never literals.
- Services own state; modules draw it.
- Anything that needs root goes in a validated `scripts/*-admin.sh` helper run through `pkexec`.

## Before you open a pull request

```sh
Hyprland --verify-config -c hypr/hyprland.lua     # Hyprland config parses
shellcheck -S warning bin/* scripts/*.sh install.sh uninstall.sh
python3 theme/build.py --check                    # tokens build; contrast report
scripts/gen-shortcuts.py                          # if you changed keybinds
```

- Include a screenshot or a short clip for anything visual.
- Keep commits focused, and describe *why* as well as *what*.
- Don't commit anything from `generated/`, `local.lua` or `session.env`.

## Reporting bugs

Use the bug template, and include:

- your distribution;
- the output of `Hyprland --version` and `qs --version`;
- the relevant lines from `~/.cache/lumen-session.log` or `qs log`.

Security issues go to a private security advisory, not a public issue.
