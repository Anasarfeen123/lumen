# What Lumen does

Everything below is in the shipped desktop. Keys are the defaults; [SHORTCUTS.md](SHORTCUTS.md) has the full list.

## The bar and the island

- **One bar that adapts.** On an empty workspace it's three floating glass pills: workspaces, the island, and status. When windows are open they merge into one floating bar.
- **The Dynamic Island** in the middle shows what's happening now:
  - a clock with a live equalizer while music plays;
  - now playing, which expands on hover with artwork, controls and a glow in the album's colour;
  - notifications with actions, volume and brightness, Caps Lock and keyboard layout;
  - Wi-Fi, Bluetooth, chargers and USB devices;
  - screenshots and recording, timers and stopwatches, downloads, reminders and updates.
- **Island gestures:** scroll for volume (with Shift for brightness), middle-click to play or pause, right-click for background apps.
- **App menu:** the focused app's name sits next to the workspaces. Click it (or press <kbd>Super</kbd>+<kbd>Alt</kbd>+<kbd>Enter</kbd>) for window actions: float, maximise, fullscreen, pin, move to a workspace, screenshot, close, force quit.
- **Tray drawer:** apps running in the background (Discord, Steam, WARP…) collapse into one button. Their menus are drawn by Lumen inside the drawer.

## Control centre and notifications (right sidebar)

- **Controls** (<kbd>Super</kbd>+<kbd>A</kbd>, or click the status pill):
  - Wi-Fi and Bluetooth lists (with device battery levels);
  - sixteen toggles: Focus, Caffeine, Night light, Mic, Airplane, Power mode, Game mode, Dark, keyboard light, WARP, Glass, Lock, Record, Screenshot, Copy text, Pick colour;
  - volume and brightness with live percentages, and per-app volume;
  - now playing, system stats and a month calendar.
- **Notifications** (<kbd>Super</kbd>+<kbd>N</kbd>): one card per app. Busy apps collapse into a stack. Swipe to dismiss, or dismiss a whole app at once. There's a Do Not Disturb pill, and an "All caught up" state when the list is empty.
- **Keyboard:** arrow keys move between toggles, Enter toggles, <kbd>Ctrl</kbd>+<kbd>Tab</kbd> switches tabs, Esc closes.

## Planner (left sidebar, <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>A</kbd>)

- **Weather** from Open-Meteo, with no account. You type a city once; nothing is sent before that.
- **Agenda** in plain language: `fri 7pm Concert`, `tomorrow 9:30 Standup`, `3/10 Birthday`. The island reminds you ten minutes before.
- **To-dos** and a **notes** pad that saves as you type. Everything is stored in plain files under `~/.local/state/lumen`.

## Finding and switching

- **Overview** (tap <kbd>Super</kbd>): search apps, windows, maths (`=`), commands (`>`), the web (`?`) and timers (`timer 25m`, `stopwatch`). Workspaces show live previews; drag a window onto one to move it.
- **Alt+Tab:** live previews in the order you last used windows. Release Alt to switch, press <kbd>Q</kbd> to close the selected window, or use <kbd>Alt</kbd>+<kbd>`</kbd> to cycle one app's windows.
- **Clipboard** (<kbd>Super</kbd>+<kbd>V</kbd>): text and image history with thumbnails.
  - <kbd>Enter</kbd> pastes into the app you were in.
  - <kbd>Ctrl</kbd>+<kbd>Enter</kbd> pastes as plain text.
  - <kbd>Alt</kbd>+<kbd>Enter</kbd> copies only.
  - <kbd>Alt</kbd>+<kbd>P</kbd> pins an item.
- **Emoji** (<kbd>Super</kbd>+<kbd>.</kbd>).

## Ask Lumen (<kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>Space</kbd>)

- Ask about selected text or a screenshot of your screen, or anything else. Quick actions: Explain, Summarize, Fix writing, What's on my screen?
- Answers come from **Ollama** (local; nothing leaves your computer) or **Claude** (your own API key). The provider is off until you choose one in Settings → AI, and conversations are never saved.

## Capture

- **Screenshots:**
  - <kbd>PrtSc</kbd> captures the screen;
  - <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>S</kbd> captures a region;
  - <kbd>Alt</kbd>+<kbd>PrtSc</kbd> captures a window;
  - <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>E</kbd> captures and opens an annotation editor.
- **Copy text from the screen** (OCR, on your machine): <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>T</kbd>.
- **Screen recording** of a region or the whole screen, with or without sound. The island shows a live timer.
- **Colour picker:** <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>C</kbd>.

## Calm and focus

- **Focus modes:**
  - Do Not Disturb;
  - Work (apps you allow still get through);
  - Game (effects off, notifications held);
  - Sleep (quiet and warm light).
  Work and Sleep can run on a schedule, and <kbd>Ctrl</kbd>+<kbd>Super</kbd>+<kbd>N</kbd> cycles through the modes.
- **Night light** by hand, from sunset to sunrise (sunrise and sunset are calculated on your machine), or at custom hours.
- **Wallpaper by time of day:** dawn, day, dusk and night slots.
- **Idle:** dim, lock, screen off and sleep, all adjustable. Sleep can be limited to battery only. A Lumen session running on another TTY never suspends the laptop.

## Lock screen and security

- **Lock screen:**
  - a big clock with now playing, battery, calendar and notification counts (never their content);
  - macOS-style transitions;
  - a glowing avatar (Settings → Lock screen → picture).
- **Face ID** (Gaze): lock screen only. Your password always works, and on battery the camera starts only when you press <kbd>F2</kbd>.
- **Admin prompts:** Lumen is the polkit agent, and draws a clear card saying what's asking.

## Settings (<kbd>Super</kbd>+<kbd>I</kbd>)

Sixteen pages, all searchable:

- **Appearance** (themes, accents, glass, pointer, icons, sounds) and **Wallpaper**;
- **Bar & Island**, **Windows** (gaps, corners, borders, animation speed), **Notifications** (Focus, schedules, per-app rules);
- **Network**, **Bluetooth**, **Sound** (including your music app), **Display**;
- **Lock screen**, **Face ID**, **Power** (modes, charge limit, idle), **AI**;
- **Keyboard & Gestures** (read live), **Updates** (dnf, pacman, apt, zypper and Flatpak, installed only when you say so), **About**.

## Little things

- **Scratchpads:**
  - <kbd>Super</kbd>+<kbd>S</kbd> for general use;
  - <kbd>F12</kbd> for a drop-down terminal;
  - <kbd>Super</kbd>+<kbd>Shift</kbd>+<kbd>M</kbd> for music, which starts YouTube Music or Spotify if it's empty.
- **Game mode**, battery charge limit, keyboard backlight and zoom (<kbd>Super</kbd>+<kbd>=</kbd> and <kbd>Super</kbd>+<kbd>−</kbd>).
- **Hybrid GPUs:** the integrated GPU renders; `lumen-dgpu <app>` runs one app on the discrete GPU.
- **Hot corners:** top-left for the overview, top-right for the control centre.
- **Gestures:**
  - 4 fingers up or down for the overview;
  - 4 fingers left or right for workspaces;
  - 3 fingers to move a window, and a 3-finger pinch for fullscreen.
