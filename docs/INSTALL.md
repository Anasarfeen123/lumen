# Installing Lumen

## Before you start

- **Hyprland 0.56 or newer.** Lumen's Hyprland config is written in Lua, which older releases can't read. The installer checks your version and tells you if it's too old.
- **Quickshell 0.2.** It draws everything you see: the bar, island, sidebars, lock screen and Settings.
- **A Wayland-capable GPU driver.** Mesa (AMD/Intel) works out of the box. On NVIDIA, use the proprietary driver 555 or newer.

Lumen installs next to what you have. It never touches `~/.config/hypr` (another Hyprland setup), KDE or GNOME settings, or system configuration.

## Guided install

```sh
git clone https://github.com/<you>/lumen.git ~/Projects/lumen
cd ~/Projects/lumen
./install.sh --dry-run    # shows every step and the exact commands; changes nothing
./install.sh              # asks before each step
./install.sh --yes        # accepts every step (still prints each command)
```

The installer works through six steps. Each one says what it's for and asks first:

1. **Hyprland.** On Fedora, Hyprland isn't in the official repositories, so the installer offers the COPR that Hyprland's own install guide points to (`solopasha/hyprland`). On Arch and openSUSE it comes from the official repositories in the next step.
2. **Packages.** Everything else comes from your distribution's own repositories. The list shows why each package is needed. Anything your repositories don't have is listed separately, with what to do about it.
3. **Fonts and cursor (optional).** Material Symbols (the icons) and Google Sans Flex (the UI font) come from Google's official repositories, and Bibata (the pointer) from its author's releases. These are font and image files only, downloaded over HTTPS and checked before use.
4. **Link.** `~/.config/lumen` points to the folder you cloned, so `git pull` updates Lumen.
5. **Theme.** Generates colours and config from `theme/tokens.toml`, using only Python's standard library.
6. **How to start.** Pick one:
   - **A TTY:** log in on, say, tty3 (<kbd>Ctrl</kbd>+<kbd>Alt</kbd>+<kbd>F3</kbd>) and Lumen starts. This adds a small, marked block to `~/.bash_profile`.
   - **Login screen:** adds a "Lumen" session for GDM or SDDM. This writes one file to `/usr/share/wayland-sessions` and needs sudo.
   - **By hand:** run `~/.config/lumen/bin/lumen-session` from a TTY.

## Distribution notes

| Distribution | Hyprland | Quickshell | Notes |
|---|---|---|---|
| **Fedora 43+** | COPR `solopasha/hyprland` | Official repos | Primary platform; everything is tested here. |
| **Arch, EndeavourOS, CachyOS, Manjaro** | `extra` | AUR (`quickshell` / `quickshell-git`) | Install AUR packages with your helper; read the PKGBUILD first. |
| **Debian, Ubuntu, Mint, Pop!_OS** | Official repos, usually older than 0.56 | Not packaged; [build it](https://quickshell.org) | Check `Hyprland --version`; you may need a newer Hyprland. |
| **openSUSE Tumbleweed** | Official repos | Official repos, or build it | Leap's Hyprland is too old. |

Other distributions work if you install the same programs yourself. The installer lists what it couldn't find and continues with the rest.

## Optional extras

None of these are installed automatically.

- **Face ID** on the lock screen: install [Gaze](https://gaze.gundulabs.com), then use Settings → Face ID.
- **Local AI** for Ask Lumen: install [Ollama](https://ollama.com), then pull a model (for example `ollama pull llama3.2`). Read Ollama's install script before running it.
- **Qt apps in Lumen colours:** install `qt6ct`. Lumen then styles Qt apps in its own session only.
- **Update checks on Arch:** install `pacman-contrib` for `checkupdates`.

## Updating

```sh
cd ~/Projects/lumen && git pull
```

Then press <kbd>Ctrl</kbd>+<kbd>Super</kbd>+<kbd>R</kbd> to reload, or log out and back in. System packages update from Settings → Updates.

## Uninstalling

```sh
./uninstall.sh              # asks before each removal
./uninstall.sh --dry-run    # shows what it would remove
```

This removes the `~/.config/lumen` link, the TTY block (after backing up `~/.bash_profile`), the login-screen entry, and the fonts and cursor Lumen downloaded. Packages stay, because other software may use them. Your preferences stay in `~/.local/state/lumen`; delete that folder for a clean slate.
