# Lumen roadmap: fixes, quality of life, features

Collected 2026-10-19 from the running shell log, `~/.cache/hyprland` crash reports, the user
journal, and a pass over `shell/` against the DESIGN.md §12 quality checklist.
Tick items off as they land.

---

## 1. Bugs (with evidence)

### Crashes
- [x] **Commit the multi-GPU sync fix.** The uncommitted `AQ_MGPU_NO_EXPLICIT=1` had been lost;
      it's back in `bin/lumen-session` (only when both GPUs are used) and committed. Takes effect
      at the next login.
- [x] **Second Hyprland crash: assert in `CHyprOpenGLImpl::begin`.** Not a second crash: all 12
      reports from 25 Sep to 26 Oct end with `eglDupNativeFenceFDANDROID … EGL_BAD_PARAMETER`
      straight before the assert, so it's the same multi-GPU fence failure (7 crashes in the
      14 days before the fix). `lumen doctor` now counts them; if one appears after a fresh
      login with the fix, try a session with `LUMEN_DGPU=off`.

### Shell (from the Quickshell log)
- [x] **Desktop-entry warning flood (426×).** A valid copy ships in `share/applications/` and
      `bin/lumen-startup` links it into `~/.local/share/applications/` (never over system files).
- [x] **Broken clipboard thumbnails.** The row falls back to the icon when the file is gone. `modules/overview/ResultRow.qml:39` loads
      `/run/user/…/lumen-clip/N.png` after the file is gone (`/run` is cleared at logout). Keep
      pinned images in `~/.cache/lumen`, or hide the thumbnail when the file is missing.
- [x] **`HaloCard.qml:143` assigns undefined to a string.** `label: modelData.label` →
      `label: modelData.label ?? ""`.
- [x] **Visualizer reads its config before writing it.** No preload; cava waits until it's saved. `services/Visualizer.qml` reads
      `$XDG_RUNTIME_DIR/lumen-cava.conf` before it exists, so the first start fails.
- [ ] **PipeWire volume warnings (~150).** Tried filtering the tracked streams; it made the shell
      crash in Quickshell's PipeWire unbind (2026-11-01), so it's back to tracking every stream.
      The noise comes from app streams with no channel map; leave it to Quickshell.
- [ ] **An SVG drawn at a huge size (36×, 252× in a longer session).** Not one of Lumen's
      `sourceSize`s (those are all photos); likely an icon-theme SVG. "qt.svg.draw: requested buffer size is too big".
      Find the Image/IconImage with an oversized `sourceSize`. There's also a malformed
      `utilities-terminal.svg` in the McMojave icon theme.

### Services
- [x] **`amazecc-api.service` fails quietly.** In amazecc-api (local change, not committed —
      it's the org's repo): `hasDatabase()` in `src/lib/db.ts`, and the club sync, club roles and
      enrolment skip quietly without one. Rebuild/restart the service to apply. Lumen says
      "Out of date" (planner, AmazeCC app) when data is over 6 hours old. It failed 3 times in 3 days, and its background
      jobs error with "DATABASE_URL is not set" (club sync, attendance enrolment). Give it a local
      DB or disable DB-backed jobs locally. Lumen should say when AmazeCC data is stale.
- [~] **Idle CPU.** Found one big cause: a spinner in a window title (Claude Code's ◐◑ in kitty)
      changed the title several times a second, and each change ran a git probe (Context) and a
      Python PiP check. Both now ignore title changes that are only a spinner. Was: **Idle CPU.** The shell averaged 1.3 % CPU over 21 h; §12 asks for ≈ 0 %. The fast timers
      (lyrics, Halo mouth, countdown) are correctly gated, so profile animations and the ~192
      `Process` launches instead.

---

## 2. Code health (DESIGN.md §12)

- [x] **62 raw hex colours outside `theme/`.** New `Theme.scrim` / `Theme.onMedia` replace 40 raw
      blacks and whites (over video, photos, shadows). Left as-is on purpose: the logo, the accent
      swatches, the vinyl record, Halo's white tints; and `AiPanel`, `VoiceSheet`, `DrawOverlay`
      until their uncommitted work lands. Mostly `LumenLogo.qml`, `HaloOrb.qml`,
      `AppearancePage.qml`, `MediaExpanded.qml`, `DrawOverlay.qml`. Keep intentional ones (logo,
      pen colours) and move UI colours to tokens so Light and OLED themes apply.
- [x] **Automated checks.** `.github/workflows/check.yml`: shellcheck (errors), Python
      byte-compile, `luac -p` on the Lua config, and a QML parse check with `qmlformat` (full
      `qmllint` needs Quickshell's types). `.github/` has templates but no workflows. Add a check on every push:
      `qmllint` on `shell/`, `shellcheck` on `scripts/` and `bin/`, and a Lua syntax check of the
      Hyprland config.
- [x] **Extend `scripts/doctor.sh check`**: Hyprland crashes in 14 days (and whether they're the
      fence error), the most repeated shell-log warning, failed `lumen*`/`amazecc*` units. to report new Hyprland crash reports, the most
      repeated shell-log warnings, and failed `lumen-*` / `amazecc-api` units. That would catch
      most of section 1 automatically.
- [x] **Audit "Esc closes" on every surface.** Every window and keyboard-taking layer handles it
      (the only exception is the dev-only `lock-preview.qml`).
- [ ] **Split `modules/ai/AiPanel.qml` (1,403 lines)** into message list, input bar and skills
      menu, but only while already working there. Also large: `Ai.qml`, `AiPage.qml`,
      `NotesWindow.qml`, `PlannerWindow.qml` (600–700 lines each).

---

## 3. Quality of life

### Reliability
- [x] Restart the shell automatically if Quickshell dies, and say so in the island
      (`scripts/shell-supervisor.sh`: backs off, gives up after 5 crashes in 5 minutes).
- [x] Restore the window/workspace layout after a crash or a fresh login: the shell saves
      "last-session" every 5 minutes; when several of its windows are missing it offers to
      reopen them (only what's missing, same workspaces).

### Synconization and Environment
- [ ] Syncing youtube videos and other medias from video to phone and vice-versa


### Island and notifications
- [x] Undo after dismissing a notification, closing a window or clearing the clipboard: 5 s
      Undo for a dismissed notification, a cleared app or all, and a deleted clipboard entry.
      (A closed window can't come back — its app's state is gone.)
- [x] Keyboard-layout and caps-lock changes shown in the island (already in `services/Keyboard.qml`).
- [x] Low-disk warning past 90 % on `/` or `/home`, with "Clean caches" (lyrics, thumbnails, art).
- [x] Pause/resume screen recording from the island: right-click. Segments are joined with
      ffmpeg (no re-encode) when you stop; the clock leaves paused time out.
- [x] Improve the looks and the crammed layout of the top bar (ribbon): the window title slides
      out on hover only, narrower chips, CPU/memory only when busy (Settings → Bar & Island).
- [x] Media clicks on the bar's now-playing chip: middle play/pause, right next, back/forward
      buttons previous/next, scroll the player's volume (the island's middle-click already pauses).

### Windows and workspaces
- [~] Snap layouts: Super+K opens a panel of layouts (halves, thirds, ⅔+⅓, quarters, side +
      stack, centre, full); click a zone or press 1–9. Dragging to the top edge isn't there:
      Hyprland doesn't report drags over IPC.

### Settings and search
- [x] Right-click (or the Menu key) on launcher results: apps (open on a new workspace, copy the
      command), windows (bring here, close), toggles (turn on/off, its settings), clipboard (copy,
      plain text, pin, delete), calculator/web (copy). Frosted menu. The control-centre toggles
      were already searchable.

### Power and display
- [x] Battery-aware visuals below 20 %: one light blur pass, the visualiser rests; your blur
      comes back on plugging in (services/LowPower.qml). Animation rates unchanged.
- [x] Per-app night-light exceptions: night light steps aside while GIMP, Krita, Inkscape,
      darktable, Figma, Blender… is focused (list in Settings → Display).
- [x] Theme schedule: Settings → Appearance → By time of day — Sun or your hours, any day and
      night theme (Light / OLED by default).
- [x] Lock-screen quick actions: play/pause was there; a Timer card starts 5/10/25 min or shows
      the running one with pause and stop.

---

## 4. Features

### From the "keep in mind" list
- [x] **AI gestures** (Settings → Halo → Touchpad gestures, off by default): rest three fingers
      still → circle to search; rest four → talk while they stay down. scripts/touch-gestures.py
      reads the touchpad read-only (input group). A drawn circle would collide with the
      three-finger swipe, so it's a rest instead.
- [x] **Better sidebars:** Settings → Bar & Island → Sidebar shows, hides and reorders the Controls
      sections; the planner's header combines the next class, the weather and the next to-do. Was:
      choose and reorder tabs and cards; a "Today" card combining the next
      AmazeCC class, weather and the next to-do.

### Halo
- [x] `halo` CLI using the panel's models and memory (`halo "why did this fail" < log`); linked
      into ~/.local/bin with `lumen` at login.
- [x] "What was I doing?": screen time now keeps a timeline per day (apps, a few window titles,
      this computer only); ask Halo "what was I doing yesterday / this morning / on Monday" and
      reopen those apps. Fills in from now on.
- [x] Live captions for any video or call through whisper.cpp: Ctrl+Super+C, "Live captions" in
      search or "turn on captions" to Halo — what the speakers play, near the bottom of the screen.
- [x] Meeting mode: detection, held notifications, paused timer and awake screen were there; now a
      mic check when a call starts (which mic, muted or live, one-tap mute) and "Write notes" when
      it ends (a dated note, opened).
- [~] Focus session: Deep work / Study already run Pomodoro rounds with Do Not Disturb; ending
      one now gives a Halo summary (time, rounds, where the time went). A website block list
      isn't there — browsers don't take one from outside without an extension.
- [x] Force a question to the AI: start it with `ai:` (or `@ai`), or press "Ask the AI instead"
      on an answer Halo gave by itself.
- [~] Improve the avatar: a new abstract look, "Core" (now the default) — a glowing core, arcs
      in orbit and a ring of ticks, swelling with your voice and turning while it thinks; the
      face stays as an option (Settings → Halo → General → Look). Still to do: "the pop up is
      very buggy" — which popup, and what goes wrong?

### College (AmazeCC)
- [x] Island nudges: "Class in 10 min · AB1-305" and "don't skip tomorrow" were already there.
- [x] Exam mode in the week before an exam: a card on the planner's Today tab — countdown, room
      and seat, today's slot in the study plan, the rest of the week, revision note, full plan.
      (Syllabus left: VTOP doesn't give it.)
- [~] More AmazeCC: "Hide CGPA and grades" (Settings → AmazeCC: dots until clicked in the app,
      never read aloud). Plus the AmazeCC app itself (Ctrl+Super+A). More to come.

### Ecosystem
- [X] Clipboard shared with the phone through Lumen Link, with the source shown in the island.
- [x] Global search across notes, clipboard, Halo memory and recent files: the launcher adds
      "Halo remembers" and "Recent files" (open, show in folder, copy path); notes were there,
      the clipboard keeps its own mode.
- [ ] Multi-monitor island: mirror it or show only a clock on the second screen.
- [x] Lumen Sync (`lumen sync export|import|list`, "Export my setup" in search): settings, theme,
      pins, planner, Halo memory, notes, wallpaper, local.lua — no keys or private history; import
      saves what it replaces first. Was: one-click export/import of the whole setup (settings, pins, notes, Halo
      memory, accent, wallpaper), building on `backup.sh` and `cloud-backup.sh`.
- [x] Widget API (docs/WIDGETS.md): sidebar cards and desktop widgets as folders in
      `~/.local/share/lumen/widgets/` (not ~/.config/lumen — that's the repo), given one stable
      `lumen` object; off until turned on in Settings → Appearance → Your widgets. Two examples.
      Island states aren't pluggable yet.
- [ ] Lumen Store page in Settings: curated apps and Halo skills, installed through the
      distro's package manager.

---

## 5. Ideas from other setups

Taken from what other well-known Hyprland/Quickshell setups ship (looked at 2026-10-19):
[end-4 illogical-impulse](https://github.com/end-4/dots-hyprland),
[Caelestia](https://github.com/caelestia-dots/shell),
[Noctalia](https://github.com/noctalia-dev/noctalia-shell),
[DankMaterialShell](https://github.com/AvengeMedia/DankMaterialShell),
[Ambxst / Ax-Shell](https://github.com/Axenide/Ambxst),
[HyprPanel](https://github.com/Jas-SinghFSU/HyprPanel),
[HyDE](https://github.com/HyDE-Project/HyDE),
[ML4W](https://github.com/mylinuxforwork/dotfiles) and
[Pyprland](https://hyprland-community.github.io/pyprland/).
Before building one, grep the repo: a quick keyword scan suggested these are missing, but
it's rough (Settings already has Display and Windows pages, for example).

### Desktop and screen
- [ ] **Anti-flashbang** (ii): dim a window that suddenly goes bright white while the screen
      is dark (a white page at night, a light-mode app opening).
- [x] **Screen translation**: "Translate text on screen" in search — circle it and it's translated
      as soon as it's read (circle to search's Translate, started for you).
- [x] **Rounded screen corners** (Settings → Bar & Island), click-through. Was: **Screen border / rounded screen corners** (Caelestia): an optional thin frame that
      gives the whole screen rounded edges. Check `modules/corners` first.
- [x] **Desktop widgets** (Settings → Appearance → Desktop): clock, date, weather, now playing on the wallpaper. Was: (Noctalia, Caelestia): optional clock, weather or now-playing on the
      wallpaper, drawn in Lumen glass.
- [x] **Desktop audio visualiser** (Settings → Appearance → Music on the wallpaper): accent bars along the bottom of an empty workspace while music plays; cava stops otherwise. Was: (Caelestia): the existing cava bars drawn faintly on the
      wallpaper while music plays.
- [~] **Magnifier**: the full-screen zoom around the pointer already exists (Super+= / Super+−, Super+Alt+scroll, Super+3-finger pinch); no separate small loupe. Was: (Pyprland *magnify*): a small zoom loupe that follows the pointer,
      next to the existing full-screen zoom.
- [x] **Exposé** (Super+Shift+Tab, "All windows" in search): every window of every workspace, live, in one grid; type to filter, arrows, Enter/click to go, middle-click closes. Was: (Pyprland): every window of every workspace tiled on one screen. Overview
      shows a workspace grid; this is "all windows, flat".
- [x] **Lost windows** (Pyprland): "Bring back lost windows" in search
      (`scripts/lost-windows.sh`) centres floating windows that are off every screen.
- [x] **Monitor layout editor** (Settings → Display → Screens): drag screens into place (edges snap), resolution/refresh and scale; Apply is live with a 15 s "Keep these settings?" that reverts by itself; saved to ~/.local/state/lumen/monitors.lua (scripts/monitors.py). Was: (Noctalia, Ambxst): drag screens into place, set refresh rate
      and scale, then write it to the Lua config. Check what `DisplayPage.qml` already does.
- [x] **Turn displays off** without sleeping: Ctrl+Super+Escape or "Turn the screen off" in
      search; any key or the mouse wakes them.

### Theming
- [~] **Theme everything from the accent**: kitty, Qt (qt6ct), KDE apps and the prompt were
      already themed; `lumen reload` now also sets GNOME's dark/light and nearest accent, which
      Firefox, Chromium/Electron and libadwaita follow. GTK's own CSS stays ii's (Matugen) and VS
      Code's settings stay yours. Was: **Theme everything from the accent** (DankMaterialShell, ML4W, HyDE): push Lumen's
      palette into GTK 3/4, Qt/Kvantum, kitty, VS Code and Firefox so apps match the shell.
      Lumen's rule is "a stable palette, not Material You" (§2.4), so derive from tokens, not
      from the wallpaper.
- [x] **Shareable theme packs**: `lumen sync theme-export` / `theme-import` and "Share my theme" in search — theme, accent, glass, corners, gaps, border and the wallpaper; import keeps a copy of your settings first. Was: (HyDE *themepatcher*): accent + wallpaper + blur strength as
      one folder people can install.
- [ ] **Matching login screen** (DankMaterialShell's greeter): a Lumen-styled greeter, or at
      least a matching theme for Plasma Login Manager.

### Tools
- [x] **QR scanner**: "Scan a QR code" in search or "scan qr" to Halo — pick the region; open a link, copy, or join a Wi-Fi code (OpenCV, on this computer; no barcodes or webcam). Was: (Ambxst): scan a region on screen, or the webcam; open the
      link or Wi-Fi details it contains.
- [x] **Webcam mirror**: "Mirror" in search — a small, pinned, mirrored preview; again closes it.
- [x] **OTP / 2FA codes**: `otp` / `2fa` in the launcher (Enter copies); `lumen otp add <name>`
      stores the secret (or an otpauth:// link) in the keyring. Checked against RFC 6238.
- [x] **tmux session picker**: "tmux" in the launcher lists sessions (Enter attaches in kitty)
      and offers a new one.
- [x] **Kanban board**: the To-do card's board view — Next / Doing / Done; click a card to move it
      on, right-click back.
- [x] **Process manager in the launcher**: `kill <name>` / `top` lists processes, busiest first,
      with PID, CPU and memory; ending one is Enter twice.
- [x] **File search in the launcher**: `f <name>` searches your home folder with fd (open, show in
      folder, copy path). No previews.
- [x] **Dictionary and unit/currency conversion**: units and money were already qalc's;
      `define <word>` asks Halo.
- [ ] **Game launcher** (HyDE): Steam/Lutris/Heroic games with cover art, starting game mode
      on launch. (Steam is installed but has no games yet.)
- [x] **Shortcuts menu**: type `> command`, right-click → "Save as a shortcut"; saved ones come up
      when you type part of them (or "saved"), Enter runs, right-click forgets or opens in kitty.

### Audio, power and hardware
- [ ] **EasyEffects presets** (Ambxst): switch EQ presets (Speakers, Headphones, Voice) from
      the output picker. (No presets saved yet.)
- [x] **Low-battery warnings with levels**: 20 % and 10 % were there; at 5 % a 60-second
      countdown to sleep, cancelled by plugging in or "Not now".
- [~] **Separate idle times on AC and battery**: idle sleep has a "battery only" option; hibernate isn't possible here (the only swap is zram, in RAM). Was: (DankMaterialShell), plus hibernate in the
      power menu when swap allows it.
- [x] **GPU and temperature details**: already in Settings → System (per-GPU use, °C, W), opened from the stats card. Was: (HyprPanel, DankMaterialShell): per-GPU usage (AMD and
      NVIDIA) and fan/temperature in the stats card.
- [ ] **Fingerprint unlock** (Caelestia) alongside Face ID, for laptops with a reader.
- [ ] **On-screen keyboard** for touchscreens and tablet mode.

### Platform
- [ ] **Hot-reloading config file** (Noctalia): one readable `lumen.toml` that Settings writes
      and power users can edit, applied without restarting.
- [x] **Full CLI/IPC**: `lumen ipc` lists every target and function the shell exposes;
      `lumen ipc <target> <function> [args]` calls one in this session's shell.
- [x] **Plugin lockfile**: `lumen widgets add <git-url>` lists every file and asks, then records
      URL, commit and a hash in widgets.lock; `lumen widgets sync` reinstalls exactly those and
      refuses files that don't match. No central registry, and no launcher providers yet.
- [ ] **Try it in a VM or live ISO** (HyDE's HyDEVM, ML4W's live ISO): a script that boots
      Lumen in a VM for testing changes and showing it off.
- [x] **Shows every command before running it**: `install.sh --dry-run` already existed.
- [x] **Safe update that can roll back**: `lumen update` fast-forwards only (refusing with
      uncommitted changes); `lumen update rollback` returns to where the last update started
      (`git reset --keep`, so it refuses rather than overwrite anything).

---