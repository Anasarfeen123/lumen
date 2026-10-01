# What Lumen does

Everything below is in the shipped desktop. Keys are the defaults; [SHORTCUTS.md](SHORTCUTS.md) has the full list.

## The Ribbon (the bar and the island)

- **One bar that adapts.** On an empty workspace it's three floating glass pills: workspaces, the island, and status. When windows are open the island stretches into one floating bar, the **Ribbon**, which carries more:
  - a **window strip**: this workspace's windows as icons after the app name (click to focus, middle-click to close);
  - **shoulders** either side of the island with only what's relevant now: now playing (with play/pause), your Focus mode or timer, the weather, your next event ("Standup · in 25 min"), a warning when the system is straining, and Halo;
  - **vitals**: a small CPU line and memory in use beside the status icons.
- **Peek:** hover a window icon or a workspace dot for live previews, each with its title, workspace, CPU and memory (the whole process tree) and what it's playing. Click to go there; middle-click closes.
- **The Dynamic Island** in the middle shows what's happening now:
  - a clock with a live equalizer while music plays;
  - now playing, which expands on hover with artwork, a glow in the album's colour, a player switcher, shuffle and repeat;
  - notifications with actions, volume and brightness, Caps Lock and keyboard layout;
  - Wi-Fi, Bluetooth, chargers, screenshots and recording, timers, downloads, reminders and updates;
  - progress for long jobs: `lumen run -- make` shows a live bar, then ✓ or ✗ with the time taken.
- **Devices:** plug something in and the island knows what it is.
  - A device this computer has never seen (keyboard, mouse, headset, camera, phone, controller) gets a card with a **New** badge.
  - **Drives and SD cards** get a card with their name, size and format, plus **Open** and **Eject** (through udisks; "Safe to remove" when done).
  - **Displays** get a card with a clean name ("Dell U2723QE") and **Arrange**.
  - Everything else, and every disconnect, is a quiet one-line pill with the device's real name and icon.
- **Context:** hover the resting island while you work. In an editor or terminal it shows the project, its git branch and changes, and live CPU, GPU and memory; in a game, frame-relevant stats. During a presentation it holds notifications and keeps the screen awake.
- **Island gestures:** scroll to scrub the **Now timeline** (the last hour: notifications, devices, screenshots, and what's coming up; ←/→ step, Esc closes), or change the volume instead (Settings → Bar & Island → Scroll on the island); middle-click to play or pause, right-click for background apps.
- **App menu:** the focused app's name sits next to the workspaces. Click it (or press <kbd>Super</kbd>+<kbd>Alt</kbd>+<kbd>Enter</kbd>) for window actions: float, maximise, fullscreen, pin, move to a workspace, screenshot, close, force quit.
- **Tray drawer:** apps running in the background (Discord, Steam, WARP…) collapse into one button. Their menus are drawn by Lumen inside the drawer.

## Control centre and notifications (right sidebar)

- **Controls** (<kbd>Super</kbd>+<kbd>A</kbd>, or click the status pill):
  - **Wi-Fi and Bluetooth tiles:** the round icon switches the radio; the rest of the tile opens its list.
  - **Wi-Fi list**, grouped into Connected, Saved networks and Other networks, with "Connecting…", a password field in place (with show/hide), and **⋯** for Disconnect, Join or Forget. Ethernet is detected too.
  - **Bluetooth list:** your devices (with battery levels), then **Nearby** devices, searched for only while the list is open. Click one to pair it; it's trusted, so it reconnects by itself next time. **⋯** offers Disconnect and Forget.
  - sixteen toggles: Focus, Caffeine, Night light, Mic, Airplane, Power mode, Game mode, Dark, keyboard light, WARP, Glass, Lock, Record, Screenshot, Copy text, Pick colour;
  - volume and brightness with live percentages, and per-app volume;
  - your phone (KDE Connect), now playing, system stats and a month calendar.
- **Notifications** (<kbd>Super</kbd>+<kbd>N</kbd>): one card per app. Busy apps collapse into a stack. Swipe to dismiss, or dismiss a whole app at once. There's a Do Not Disturb pill, and an "All caught up" state when the list is empty.
- **Keyboard:** arrow keys move between toggles, Space toggles, Enter opens a tile's list, <kbd>Ctrl</kbd>+<kbd>Tab</kbd> switches tabs, Esc closes.

## Planner (left sidebar, <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>A</kbd>)

- **Weather** from Open-Meteo, with no account. You type a city once; nothing is sent before that.
- **Agenda** in plain language: `fri 7pm Concert`, `tomorrow 9:30 Standup`, `3/10 Birthday`. The island reminds you ten minutes before.
- **To-dos** and a **notes** pad that saves as you type. Everything is stored in plain files under `~/.local/state/lumen`.

## Finding and switching

- **Overview** (tap <kbd>Super</kbd>): search apps, windows, settings and actions, ranked into groups as you type.
  - Maths (`=`), commands (`>`), the web (`?`) and timers (`timer 25m`, `stopwatch`).
  - Commands that take values: `volume 40`, `brightness 70`, `open project lumen` (editor and terminal in that folder), `close slack`, `kill <process>`.
  - Actions with their state: "Night light · On", "Do Not Disturb · Off"; every Settings page is searchable.
  - `ask …` sends a question straight to Lumen Halo.
  - Workspaces show live previews; drag a window onto one to move it.
- **Workspace snapshots:** `save coding` in the overview (or `lumen snapshot save coding`) remembers which apps are open, on which workspace, their size, and each terminal's folder; `restore coding` brings the whole setup back.
- **Workspaces:** <kbd>Ctrl</kbd>+<kbd>Super</kbd>+<kbd>←</kbd>/<kbd>→</kbd> moves between workspaces; add <kbd>Alt</kbd> to jump only between workspaces that have windows, wrapping from the last to the first.
- **Alt+Tab:** live previews in the order you last used windows. Release Alt to switch, press <kbd>Q</kbd> to close the selected window, or use <kbd>Alt</kbd>+<kbd>`</kbd> to cycle one app's windows.
- **Clipboard** (<kbd>Super</kbd>+<kbd>V</kbd>): text and image history with thumbnails.
  - Items are recognised: links, emails, colours (with a swatch), paths, numbers, commands, code. Filter chips (<kbd>Ctrl</kbd>+<kbd>←</kbd>/<kbd>→</kbd>) narrow the list.
  - Anything that looks like a password or token is masked, and password-manager copies are never stored.
  - <kbd>Enter</kbd> pastes into the app you were in, <kbd>Ctrl</kbd>+<kbd>Enter</kbd> pastes as plain text, <kbd>Shift</kbd>+<kbd>Enter</kbd> opens a link, <kbd>Alt</kbd>+<kbd>Enter</kbd> copies only, <kbd>Alt</kbd>+<kbd>P</kbd> pins.
- **Emoji** (<kbd>Super</kbd>+<kbd>.</kbd>).
- **Money in rupees:** the calculator understands ₹, rs, lakh and crore, converts other currencies to ₹ (`50 USD`), and shows Indian grouping (₹1,23,456.78) with a lakh/crore reading.

## Drop Zone

Drag files to the right edge of the screen and a shelf slides out: **Send to phone**, **Copy** (as files), **Compress** (a .zip next to them), **Open with** (apps for that file type), **Move to** (Documents, Downloads, Desktop, Pictures, Projects; never overwrites), or **Keep on shelf** to park them at the edge and drag them out later.

## Lumen Link (your phone, via KDE Connect)

- **Connects where Wi-Fi won't:** Settings → Lumen Link notices networks that keep devices apart (hostels, campuses, cafés) and offers ways around it: connect by the phone's address, a USB cable with USB tethering, Bluetooth, or the phone's hotspot.
- The island announces your phone with its battery, warns when it's low, and tells you when a file arrives (Open / Show).
- The sidebar card shows the battery and how it's linked, with Ring, send a file, send the clipboard and send a screenshot. Phone notifications arrive in the notification centre.

## WhatsApp (through your WhatsApp Web session)

Lumen is the interaction layer around WhatsApp; WhatsApp Web (Whatsie, or a web-app window) stays the account and does the sending.

- **Messages** are grouped per chat with the sender's photo or initial, a preview (if you allow it) and an unread count, with **Reply**, **Dismiss** and **Mute**. The island shows new messages and calls; the Ribbon shows "Arya · 2" or "3 in 2 chats".
- **Quick reply** (<kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>W</kbd>): pick a chat, type, confirm, and WhatsApp opens with your message filled in — **you press Enter there**. Lumen never sends anything itself.
- **Send to WhatsApp** from the Drop Zone, a screenshot card or search: text and links are filled in; files go on the clipboard to paste.
- **Search:** `wa arya`, `whatsapp unread` — chat names only, never message text.
- **Halo:** "tell Arya I'll send the build tonight" (or `/wa Arya: …`) shows a Send? card; "what did Arya say" and "catch me up on WhatsApp" use messages seen this session, only if you turn on Halo message context.
- **Settings → WhatsApp:** separate switches for the integration, notifications and the Ribbon; previews; which chats may interrupt each Focus mode; muted chats; a small name → number book.
- **What it can't do** (WhatsApp has no official API for personal accounts): mark chats read inside WhatsApp, answer calls (Answer brings WhatsApp forward), or see messages from before Lumen started watching. Messages are kept in memory only and never written to disk.

## Backup & recovery

- **File backups:** pick a drive or folder in Settings → Backup & recovery; snapshots only copy what changed (hard links), progress shows in the island, and restores go to `~/Restored` so they never overwrite anything. Optional daily backups; plugging in your backup drive offers "Back up now" when one is due.
- **Lumen Recovery:** `lumen recovery` (works from a TTY) or the same page: back up and restore Lumen's settings (backed up daily at login), safe mode for the next login (no shell, a terminal with the recovery menu), a minimal Hyprland session, reset the generated theme, go back to an earlier version on a new git branch, logs and a health check. Nothing is deleted: old copies go to the trash.

## Lumen Halo (<kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>Space</kbd>)

The assistant built into the desktop. A ring of light turns around the panel while it works.

- **Where answers come from:** a local model through **Ollama** (nothing leaves your computer) or **Claude** with your own API key. It's off until you choose, and conversations are never saved.
- **Automatic model choice (local):** your smallest text model answers (it fits in video memory, so it's fast); a model that reads images takes over only when you attach your screen. The model loads in the background as soon as you open Halo. Answers show their speed in tokens per second.
- **Skills:** type `/` for the list.
  - `/explain`, `/summarize`, `/eli5`, `/define`
  - `/fix` (grammar), `/rewrite formal`, `/translate spanish`, `/reply` (draft a reply to the selected message)
  - `/cmd find big files in Downloads` (one shell command, explained)
  - `/diagnose` (reads a system snapshot: failed services, recent errors, network, disk, memory, busy processes, battery, then tells you what's wrong and how to fix it)
  - `/screen`, `/window` (help with the app you're in)
  - `/commit`, `/review` (a commit message or a code review from your project's diff)
  - `/clip` (ask about what you copied)
- **Context you choose:** Selection (whatever you highlighted), Clipboard, Screen, Window, System, and Project (the folder of the terminal or editor you're in). Each is a chip. Nothing is read until its chip is on, and nothing is sent until you press Enter.
- **What you can do with an answer:** Copy; **Insert** it into the app you came from; **Save to notes** (the planner's notes); **Retry**. Code blocks can be copied, and shell commands can be **run in a terminal** after you confirm; commands that delete or change things say so first.
- **Works in the background:** close Halo mid-answer and the island shows it thinking, then tells you when the answer is ready.
- **Keyboard:** <kbd>Enter</kbd> sends, <kbd>Shift</kbd>+<kbd>Enter</kbd> adds a line, <kbd>↑</kbd> recalls earlier questions, <kbd>Ctrl</kbd>+<kbd>L</kbd> starts over, <kbd>Ctrl</kbd>+<kbd>R</kbd> retries, Esc closes.
- **Settings → Halo:** installed models (use or remove), recommended downloads with progress in the island, or any model by name.

## Capture

- **Screenshots:**
  - <kbd>PrtSc</kbd> captures the screen;
  - <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>S</kbd> captures a region;
  - <kbd>Alt</kbd>+<kbd>PrtSc</kbd> captures a window;
  - <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>E</kbd> captures and opens an annotation editor.
  - Every screenshot lands in the island as a card: Annotate, Copy text, show in folder, delete.
- **Copy text from the screen** (OCR, on your machine): <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>T</kbd>.
- **Screen recording** of a region or the whole screen, with or without sound. The island shows a live timer.
- **Colour picker:** <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>C</kbd>.

## Calm and focus

- **Focus modes**, each with a checklist of exactly what it does:
  - Do Not Disturb;
  - **Deep work:** notifications held, wallpaper dimmed, screen kept awake, and a 25/5 Pomodoro in the island;
  - **Study:** 50/10 cycles, and the planner opens;
  - Work (apps you allow still get through), Game (effects off, performance power mode), Sleep (quiet and warm light).
  Work and Sleep can run on a schedule, and <kbd>Ctrl</kbd>+<kbd>Super</kbd>+<kbd>N</kbd> cycles through the modes.
- **Evening:** after local sunset the accent warms a little, motion calms, and banners are briefer (Settings → Appearance → Adapt to the time of day).
- **Night light** by hand, from sunset to sunrise (calculated on your machine), or at custom hours.
- **Wallpaper by time of day:** dawn, day, dusk and night slots.
- **Idle:** dim, lock, screen off and sleep, all adjustable. Sleep can be limited to battery only. A Lumen session running on another TTY never suspends the laptop.

## Look and feel

- **Theme engine:** every colour is computed in OKLCH from the tokens, and every combination passes a contrast check. Themes: Dark, Midnight, OLED, Light. Accents: Ion, Ember, Iris, Jade, or taken from your wallpaper, with a style (Exact, Adaptive, Subtle, Mono), an intensity, a glass level and an animation speed.
- **Your apps match:** Dolphin, Kate, Okular, Ark and other Qt/KDE apps use a generated Lumen colour scheme, the Darkly style and your icon theme, only inside Lumen; Plasma and your own settings are untouched. Kitty and starship follow the theme too.

## Lock screen and security

- **Lock screen:**
  - a big clock with now playing, battery, calendar and notification counts (never their content);
  - macOS-style transitions;
  - a glowing avatar (Settings → Lock screen → picture).
- **Face ID** (Gaze): lock screen only. Your password always works, and on battery the camera starts only when you press <kbd>F2</kbd>.
- **Admin prompts:** Lumen is the polkit agent, and draws a clear card saying what's asking.
- **Settings → Security:** firewall, SSH, Secure Boot, disk encryption, SELinux and recent logins at a glance (read-only).

## Settings (<kbd>Super</kbd>+<kbd>I</kbd>)

Twenty-one pages in five groups, all searchable; the sidebar scrolls and keeps your page in view.

- **Personalise:** Appearance (themes, accents, glass, pointer, icons, sounds), Wallpaper, Bar & Island, Windows (gaps, corners, borders, animation speed, snapshots).
- **Connections:** Network, Bluetooth, Lumen Link (your phone).
- **Devices:** Sound (including your music app), Display, Keyboard & Gestures (read live from the config), Power (modes, charge limit, idle).
- **Focus & privacy:** Notifications (Focus, schedules, per-app rules), Lock screen, Face ID, Security.
- **System:** Halo, Backup & recovery, System (hardware, CPU/GPU/NVIDIA, memory, disks, battery health), Updates (dnf, pacman, apt, zypper and Flatpak, installed only when you say so), **Advanced** (config files, a health check, logs, reload, rebuild, safe resets), About.

## Little things

- **Scratchpads:**
  - <kbd>Super</kbd>+<kbd>S</kbd> for general use;
  - <kbd>F12</kbd> for a drop-down terminal;
  - <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd> for music, which starts YouTube Music (as a Brave Origin / Brave / Chrome web app) or Spotify if it's empty.
- **Game mode**, battery charge limit, keyboard backlight and zoom (<kbd>Super</kbd>+<kbd>=</kbd> and <kbd>Super</kbd>+<kbd>−</kbd>).
- **Hybrid GPUs:** the integrated GPU renders; `lumen-dgpu <app>` runs one app on the discrete GPU.
- **Scroll shortcuts** (one grammar: Super moves you, +Shift carries the window, +Ctrl is the system, +Alt is finer):
  - <kbd>Super</kbd>+scroll: workspaces · +<kbd>Shift</kbd>: carry the window along · <kbd>Ctrl</kbd>+<kbd>Super</kbd>+<kbd>Alt</kbd>+scroll: only workspaces with windows;
  - <kbd>Super</kbd>+<kbd>Alt</kbd>+<kbd>Shift</kbd>+scroll: cycle this workspace's windows;
  - <kbd>Ctrl</kbd>+<kbd>Super</kbd>+scroll: volume · +<kbd>Shift</kbd>: brightness · <kbd>Super</kbd>+<kbd>Alt</kbd>+scroll: zoom;
  - <kbd>Super</kbd>+middle-click: float / tile · <kbd>Ctrl</kbd>+<kbd>Super</kbd>+middle-click: play / pause.
- **More keys:** <kbd>Super</kbd>+<kbd>H</kbd> minimise (<kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>H</kbd> shows them), <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>F</kbd> float, size and centre, <kbd>Super</kbd>+<kbd>Alt</kbd>+<kbd>Shift</kbd>+arrows swap windows, <kbd>Super</kbd>+<kbd>Home</kbd>/<kbd>End</kbd> first / last busy workspace, <kbd>Super</kbd>+<kbd>Backspace</kbd> back to the last workspace, <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>Return</kbd> floating terminal, <kbd>Super</kbd>+<kbd>R</kbd> run a command, <kbd>Super</kbd>+<kbd>X</kbd> Drop Zone shelf, <kbd>Ctrl</kbd>+<kbd>Super</kbd>+<kbd>Space</kbd> ask Halo about the screen, <kbd>Super</kbd>+<kbd>B</kbd> planner, <kbd>Ctrl</kbd>+<kbd>Super</kbd>+<kbd>W</kbd> send the clipboard to WhatsApp.
- **Hot corners:** top-left for the overview, top-right for the control centre.
- **Gestures:**
  - 4 fingers up or down for the overview;
  - 4 fingers left or right for workspaces;
  - 3 fingers to move a window, and a 3-finger pinch for fullscreen.
