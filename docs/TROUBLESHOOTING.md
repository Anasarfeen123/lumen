# Troubleshooting

Start with the logs:

```sh
cat ~/.cache/lumen-session.log              # Hyprland session
cat $XDG_RUNTIME_DIR/lumen-startup.log      # things started at login
qs log --pid "$(pgrep -n -x qs)"            # the shell
Hyprland --verify-config -c ~/.config/lumen/hypr/hyprland.lua
```

### Lumen doesn't start / black screen
- Check `Hyprland --version`: Lumen needs **0.56+**.
- Check that `qs --version` works (Quickshell).
- On hybrid laptops, try `LUMEN_DGPU=off` in `~/.config/lumen/session.env`.

### Icons show as words ("battery_full")
The Material Symbols font is missing. Re-run `./install.sh`; the fonts step fetches it.

### The shell disappeared or restarted
Quickshell restarts itself after a crash, and the report is in `~/.cache/quickshell/crashes/`. To reload by hand, press <kbd>Ctrl</kbd>+<kbd>Super</kbd>+<kbd>R</kbd>.

### Notifications don't appear
Only one program can own the notification service. If another desktop's shell is running (another TTY, for example), Lumen mirrors its notifications instead: they show without action buttons. Log out of the other session to give Lumen the service.

### File pickers or screen sharing fail in Flatpak apps
The desktop portal needs `graphical-session.target`, which `lumen-session.target` starts. Check with:

```sh
systemctl --user status lumen-session.target xdg-desktop-portal
```

### My laptop sleeps while I'm using another desktop
Fixed: idle steps now skip any session that isn't on screen. If you're on an old checkout, `git pull` and log in again.

### The drop-down terminal or music key does nothing
Use <kbd>F12</kbd> and <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd>: the backtick key is unreliable on some layouts. The music scratchpad opens the app chosen in Settings → Sound.

### Face ID never recognises me
Settings → Face ID → Details shows Gaze's per-step scores. On ordinary RGB webcams the anti-photo check (liveness) often fails; turning it off is your choice (Settings → Face ID). Your password always works.

### Qt apps don't match the colours
Install `qt6ct`, then log in again. Lumen styles Qt only inside its own session.
