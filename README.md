<div align="center">

<img src="assets/lumen.svg" width="96" alt="Lumen logo: a glowing white pill on a dark squircle">

# Lumen

**A calm, capable desktop for Hyprland.**
Extremely capable underneath. Extremely simple on the surface.

[![Hyprland 0.56+](https://img.shields.io/badge/Hyprland-0.56%2B-58E1FF?style=flat-square)](https://hyprland.org)
[![Quickshell](https://img.shields.io/badge/shell-Quickshell-f9a779?style=flat-square)](https://quickshell.org)
[![Fedora · Arch · Debian/Ubuntu · openSUSE](https://img.shields.io/badge/distros-Fedora%20·%20Arch%20·%20Debian%2FUbuntu%20·%20openSUSE-9aa1a9?style=flat-square)](docs/INSTALL.md)
[![License: GPL-3.0](https://img.shields.io/badge/license-GPL--3.0-eef1f4?style=flat-square)](LICENSE)

[Install](#install) · [Tour](#a-quick-tour) · [Shortcuts](docs/SHORTCUTS.md) · [Documentation](#documentation) · [Showcase page](https://anasarfeen123.github.io/lumen/showcase/)

<br>

<img src="docs/showcase/img/01-desktop.jpg" alt="The Lumen desktop: a floating glass bar with the Dynamic Island in the middle, over tiled btop, fastfetch and Kate windows">

</div>

<br>

Lumen turns Hyprland into one coherent desktop: a floating glass bar with a **Dynamic Island** at its heart, a control centre and a planner, an Alt+Tab switcher, a lock screen with Face ID, a settings app, and Lumen Halo, an assistant that can run entirely on your machine. It all comes from one design system, so it looks and moves like a single product.

## Highlights

<table>
<tr>
<td width="50%" valign="top">

### The island
One pill at the top of the screen tells you what just happened: music, notifications, volume, timers, downloads, recording, a drive or keyboard you just plugged in. It grows only as much as the moment needs, then settles back into a clock.

</td>
<td width="50%"><img src="docs/showcase/img/10-island-states.jpg" alt="Six island states"></td>
</tr>
<tr>
<td><img src="docs/showcase/img/04-control-centre.jpg" alt="Control centre"></td>
<td valign="top">

### Two sidebars
**Controls** (<kbd>Super</kbd>+<kbd>A</kbd>): Wi-Fi and Bluetooth (pair nearby devices in one click), sixteen toggles, per-app volume, media, stats and a calendar.
**Notifications** (<kbd>Super</kbd>+<kbd>N</kbd>): grouped by app, swipe to dismiss.
**Planner** (<kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>A</kbd>): weather, agenda (“fri 7pm Concert”), to-dos and notes.

</td>
</tr>
<tr>
<td valign="top">

### Everything is one keystroke away
Tap <kbd>Super</kbd> to search apps and windows, do maths, run commands or start a timer. <kbd>Alt</kbd>+<kbd>Tab</kbd> shows live previews in the order you used them. The clipboard (<kbd>Super</kbd>+<kbd>V</kbd>) keeps images, pins favourites and pastes straight into the app you were in.

</td>
<td><img src="docs/showcase/img/03-overview.jpg" alt="Overview and search"></td>
</tr>
<tr>
<td><img src="docs/showcase/img/19-halo.jpg" alt="Lumen Halo explaining an error, with commands you can copy or run"></td>
<td valign="top">

### Lumen Halo
The assistant built into the desktop (<kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>Space</kbd>). Select an error and ask, let it read your screen, or type `/` for skills: `/diagnose` checks your system, `/cmd` writes a command you can run, `/commit` writes a commit message from your diff. Answers come from a **local model through Ollama** (it picks a fast one automatically) or from **Claude** with your own key. Nothing is sent until you press Enter, and conversations are never saved.

</td>
</tr>
<tr>
<td valign="top">

### Calm and secure by default
Focus modes (Work, Game, Sleep) on a schedule. Night light that follows the sunset. A lock screen with widgets and **Face ID** that only ever unlocks the lock screen. Admin password prompts drawn by the desktop itself.

</td>
<td><img src="docs/showcase/img/09-lock-screen.jpg" alt="Lock screen"></td>
</tr>
</table>

### And lately
- **The Ribbon:** with windows open the island stretches into one bar: your windows, now playing, weather, your next event, a call on air, battery time left, and **Peek** (hover for live previews with CPU and memory).
- **WhatsApp**, through your own WhatsApp Web session: messages in the island and Ribbon, quick reply (<kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>W</kbd>), "Send to WhatsApp", and Halo drafts ("tell Arya I'll send the build tonight"). Lumen never sends; you press Enter.
- **Drop Zone:** drag files to the right edge to send, compress, open with, move or ask Halo.
- **Lumen Link:** your phone over KDE Connect even on hostel/campus Wi-Fi (Bluetooth network set up automatically, internet stays on Wi-Fi), clipboard from your phone.
- **The island, deeper:** synced lyrics, a scrubbable Now timeline of the last hour, Meeting mode, battery forecast.
- **Backups & recovery:** hard-link snapshots to a USB drive; `lumen recovery` from a TTY.
- **Everyday:** every laptop key with feedback, money in ₹ (`$100`, `2 lakh / 12`), screen time and focus in the planner, Halo summarising PDFs and renaming files (you apply).

## A quick tour

| | | |
|:-:|:-:|:-:|
| <img src="docs/showcase/img/05-notifications.jpg" alt="Notifications"><br>Notifications | <img src="docs/showcase/img/06-planner.jpg" alt="Planner"><br>Planner | <img src="docs/showcase/img/08-switcher.jpg" alt="Alt+Tab"><br>Alt+Tab |
| <img src="docs/showcase/img/18-settings-appearance.jpg" alt="Settings"><br>Settings | <img src="docs/showcase/img/14-wallpapers.jpg" alt="Wallpapers"><br>Wallpapers | <img src="docs/showcase/img/11-cheatsheet.jpg" alt="Cheatsheet"><br>Every shortcut (<kbd>Super</kbd>+<kbd>/</kbd>) |
| <img src="docs/showcase/img/16-focus-modes.jpg" alt="Focus"><br>Focus modes | <img src="docs/showcase/img/15-password-prompt.jpg" alt="Admin prompt"><br>Admin prompt | <img src="docs/showcase/img/18-settings-updates.jpg" alt="Updates"><br>Updates |
| <img src="docs/showcase/img/20-device-card.jpg" alt="A display announced by the island"><br>Device alerts | <img src="docs/showcase/img/21-control-wifi.jpg" alt="Wi-Fi list"><br>Wi-Fi & Bluetooth | <img src="docs/showcase/img/23-dolphin.jpg" alt="Dolphin in Lumen colours"><br>Your apps match |
| <img src="docs/showcase/img/32-whatsapp-island.jpg" alt="WhatsApp in the island"><br>WhatsApp | <img src="docs/showcase/img/26-drop-zone.jpg" alt="Drop Zone"><br>Drop Zone | <img src="docs/showcase/img/29-halo-whatsapp.jpg" alt="Halo drafting a WhatsApp message"><br>Halo + WhatsApp |

More in the [feature guide](docs/FEATURES.md) and the [showcase page](https://anasarfeen123.github.io/lumen/showcase/).

## Install

```sh
git clone https://github.com/Anasarfeen123/lumen.git ~/Projects/lumen
cd ~/Projects/lumen
./install.sh --dry-run   # see every step and command first; changes nothing
./install.sh             # guided: explains each step and asks before doing it
```

- **Distributions:** Fedora 43+ (primary), Arch and derivatives, Debian / Ubuntu and derivatives, openSUSE Tumbleweed.
- **Needs:** Hyprland **0.56 or newer** (Lumen's config is Lua) and Quickshell.
- **How it installs:** packages come from your distribution's repositories. Fonts and the cursor are optional downloads from their official projects. Nothing is ever piped into a shell.
- **Undo:** `./uninstall.sh` removes it and leaves your packages alone.

Details and troubleshooting: **[docs/INSTALL.md](docs/INSTALL.md)**.

### Try it without installing
Inside any Wayland desktop, `bin/lumen-session` runs Lumen in a window, so nothing about your current setup changes.

## Essential shortcuts

| | |
|---|---|
| Tap <kbd>Super</kbd> | Search apps, windows, maths, commands |
| <kbd>Super</kbd>+<kbd>A</kbd> · <kbd>Super</kbd>+<kbd>N</kbd> | Control centre · Notifications |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>A</kbd> | Planner: weather, agenda, to-dos, notes |
| <kbd>Ctrl</kbd>+<kbd>Super</kbd>+<kbd>Alt</kbd>+<kbd>←</kbd>/<kbd>→</kbd> | Previous / next workspace that has windows |
| <kbd>Alt</kbd>+<kbd>Tab</kbd> | Switch windows |
| <kbd>Super</kbd>+<kbd>V</kbd> | Clipboard history |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>Space</kbd> | Lumen Halo (assistant) |
| <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>S</kbd> · <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>T</kbd> | Screenshot a region · Copy text from the screen |
| <kbd>F12</kbd> · <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd> | Drop-down terminal · Music |
| <kbd>Super</kbd>+<kbd>L</kbd> · <kbd>Super</kbd>+<kbd>I</kbd> | Lock · Settings |
| <kbd>Super</kbd>+<kbd>/</kbd> | Every shortcut |

All 88 shortcuts and the gestures: **[docs/SHORTCUTS.md](docs/SHORTCUTS.md)**.

## Documentation

| | |
|---|---|
| [Install](docs/INSTALL.md) | Supported distributions, what the installer does, starting Lumen, uninstalling |
| [Features](docs/FEATURES.md) | Everything Lumen does, area by area |
| [Shortcuts](docs/SHORTCUTS.md) | Every key and gesture (generated from the config) |
| [Configuration](docs/CONFIGURATION.md) | Settings app, the `lumen` command, local overrides, themes |
| [Architecture](docs/ARCHITECTURE.md) | How the pieces fit: tokens, Hyprland Lua, the Quickshell shell |
| [Security & privacy](docs/SECURITY.md) | What runs as root, Face ID's limits, AI keys, what goes online |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | Common problems and fixes |
| [Development](docs/DEVELOPMENT.md) | Test sessions, live reload, dev hooks, contributing |
| [Design](DESIGN.md) | The design system and every decision behind it |

## Credits

Built on [Hyprland](https://hyprland.org) and [Quickshell](https://quickshell.org). Inspired by the depth of [end-4's illogical-impulse](https://github.com/end-4/dots-hyprland). Icons are [Material Symbols](https://fonts.google.com/icons), the pointer is [Bibata](https://github.com/ful1e5/Bibata_Cursor), weather comes from [Open-Meteo](https://open-meteo.com), and Face ID uses [Gaze](https://gaze.gundulabs.com).

## License

Lumen is free software under the [GNU General Public License v3.0](LICENSE): you may use, study, share and modify it; shared modifications stay under the same license.
