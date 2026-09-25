-- ── Keybinds ─────────────────────────────────────────────────────────────────
-- Mirrors illogical-impulse muscle memory where it makes sense. Shell actions
-- use hl.dsp.global("lumen:<name>") so Quickshell receives them directly.
-- Every bind carries "Section: Label" — the cheatsheet (Super+/) reads these
-- live from Hyprland, so it can never drift from what is bound here.

local bin = LUMEN_ROOT .. "/bin"
local scripts = LUMEN_ROOT .. "/scripts"
local ipc = bin .. "/lumen-shell-ipc"            -- this session's shell only

local terminal    = "kitty"
local fileManager = bin .. "/lumen-launch dolphin nautilus 'kitty -e yazi'"
local browser     = bin .. "/lumen-launch brave-browser firefox chromium"
local editor      = bin .. "/lumen-launch code codium zed kate"
local taskManager = bin .. "/lumen-launch plasma-systemmonitor 'kitty -e btop'"

local section = "General"
local function group(name) section = name end
-- key(keys, dispatcher, label[, opts]); label=nil keeps a bind out of the sheet
local function key(keys, dsp, label, opts)
    opts = opts or {}
    if label then opts.description = section .. ": " .. label end
    hl.bind(keys, dsp, opts)
end
local exec, global = hl.dsp.exec_cmd, hl.dsp.global

-- ── Apps ──
group("Apps")
key("SUPER + Return", exec(terminal), "Terminal")
key("SUPER + T", exec(terminal))
key("CTRL + ALT + T", exec(terminal))
key("SUPER + E", exec(fileManager), "Files")
key("SUPER + W", exec(browser), "Browser")
key("SUPER + C", exec(editor), "Code editor")
key("CTRL + SHIFT + Escape", exec(taskManager), "Task manager")
key("CTRL + SUPER + V", exec("pavucontrol"), "Volume mixer")
-- Overview & search: tap Super (release without another key) — like ii
key("SUPER + SUPER_L", global("lumen:overviewTap"), "Overview & search (tap Super)", { release = true })
key("SUPER + Space", global("lumen:overview"), "Overview & search")
key("SUPER + V", global("lumen:clipboard"), "Clipboard history")
key("SUPER + period", global("lumen:emoji"), "Emoji picker")
key("SUPER + I", global("lumen:settings"), "Lumen Settings")

-- ── Windows ──
group("Windows")
key("SUPER + Q", hl.dsp.window.close(), "Close window")
key("ALT + F4", hl.dsp.window.close())
key("SUPER + SHIFT + ALT + Q", exec("hyprctl kill"), "Force-kill (click a window)")
key("SUPER + ALT + Space", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.center())
end, "Float / tile")
key("SUPER + F", hl.dsp.window.fullscreen({ mode = "fullscreen", action = "toggle" }), "Fullscreen")
key("SUPER + D", hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" }), "Maximise (keeps bar and gaps)")
key("SUPER + P", hl.dsp.window.pin(), "Keep on all workspaces")
key("SUPER + U", hl.dsp.window.pseudo(), "Pseudo-tile")
key("SUPER + J", hl.dsp.layout("togglesplit"), "Flip split")
key("SUPER + ALT + Return", global("lumen:appMenu"), "Menu of the focused app")
key("SUPER + SHIFT + G", exec(bin .. "/lumen transparency toggle"), "Window transparency on/off")

key("SUPER + left",  hl.dsp.focus({ direction = "left" }),  "Focus ← → ↑ ↓")
key("SUPER + right", hl.dsp.focus({ direction = "right" }))
key("SUPER + up",    hl.dsp.focus({ direction = "up" }))
key("SUPER + down",  hl.dsp.focus({ direction = "down" }))
key("SUPER + SHIFT + left",  hl.dsp.window.move({ direction = "left" }), "Move window ← → ↑ ↓")
key("SUPER + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
key("SUPER + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
key("SUPER + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))
key("SUPER + ALT + left",  hl.dsp.window.resize({ x = -40, y = 0 }), "Resize window ← → ↑ ↓", { repeating = true })
key("SUPER + ALT + right", hl.dsp.window.resize({ x = 40, y = 0 }),  nil, { repeating = true })
key("SUPER + ALT + up",    hl.dsp.window.resize({ x = 0, y = -40 }), nil, { repeating = true })
key("SUPER + ALT + down",  hl.dsp.window.resize({ x = 0, y = 40 }),  nil, { repeating = true })
key("SUPER + Semicolon",  hl.dsp.layout("splitratio -0.1"), "Resize split", { repeating = true })
key("SUPER + Apostrophe", hl.dsp.layout("splitratio +0.1"), nil, { repeating = true })
key("SUPER + mouse:272", hl.dsp.window.drag(), "Move with the mouse", { mouse = true })
key("SUPER + mouse:273", hl.dsp.window.resize(), "Resize with the mouse", { mouse = true })
key("SUPER + G", hl.dsp.group.toggle(), "Group windows (tabs)")
key("SUPER + ALT + Tab", hl.dsp.group.next(), "Next tab in group")

-- ── Workspaces ──
group("Workspaces")
for i = 1, 10 do
    local k = tostring(i % 10)
    key("SUPER + " .. k, hl.dsp.focus({ workspace = i }), i == 1 and "Go to workspace 1…0" or nil)
    key("SUPER + SHIFT + " .. k, hl.dsp.window.move({ workspace = i }), i == 1 and "Send window to 1…0 (follow)" or nil)
    key("SUPER + ALT + " .. k, hl.dsp.window.move({ workspace = i, follow = false }), i == 1 and "Send window to 1…0 (stay)" or nil)
end
key("SUPER + Tab", global("lumen:overview"), "Overview")
key("CTRL + SUPER + right", hl.dsp.focus({ workspace = "r+1" }), "Next workspace")
key("CTRL + SUPER + left",  hl.dsp.focus({ workspace = "r-1" }), "Previous workspace")
key("SUPER + Page_Down", hl.dsp.focus({ workspace = "r+1" }))
key("SUPER + Page_Up",   hl.dsp.focus({ workspace = "r-1" }))
key("SUPER + SHIFT + Page_Down", hl.dsp.window.move({ workspace = "r+1" }), "Send window to next workspace")
key("SUPER + SHIFT + Page_Up",   hl.dsp.window.move({ workspace = "r-1" }), "Send window to previous workspace")
key("SUPER + mouse_down", hl.dsp.focus({ workspace = "r+1" }))
key("SUPER + mouse_up",   hl.dsp.focus({ workspace = "r-1" }))
key("SUPER + mouse:275", hl.dsp.focus({ workspace = "r-1" }), "Previous / next workspace (Back / Forward buttons)")
key("SUPER + mouse:276", hl.dsp.focus({ workspace = "r+1" }))
key("SUPER + S", hl.dsp.workspace.toggle_special("scratch"), "Scratchpad")
key("SUPER + ALT + S", hl.dsp.window.move({ workspace = "special:scratch", follow = false }), "Send window to scratchpad")
key("SUPER + grave", hl.dsp.workspace.toggle_special("term"), "Drop-down terminal")
key("SUPER + SHIFT + grave", hl.dsp.workspace.toggle_special("music"), "Music scratchpad")

-- ── Media & hardware keys (work on the lock screen) ──
-- These only change state; the shell listens to PipeWire / backlight and
-- shows the island. Brightness goes through the shell so the island knows it
-- was you (hypridle's dimming stays silent); falls back without the shell.
group("Media")
local lr = { locked = true, repeating = true }
key("XF86AudioRaiseVolume", exec("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), nil, lr)
key("XF86AudioLowerVolume", exec("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), nil, { locked = true, repeating = true })
key("XF86AudioMute", exec("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), nil, { locked = true })
key("XF86AudioMicMute", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), nil, { locked = true })
key("SUPER + ALT + M", exec("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), "Mute microphone", { locked = true })
key("XF86MonBrightnessUp", exec(ipc .. " brightness up || brightnessctl -e4 -n2 set 5%+"), nil, { locked = true, repeating = true })
key("XF86MonBrightnessDown", exec(ipc .. " brightness down || brightnessctl -e4 -n2 set 5%-"), nil, { locked = true, repeating = true })
key("XF86AudioPlay",  exec("playerctl play-pause"), nil, { locked = true })
key("XF86AudioPause", exec("playerctl play-pause"), nil, { locked = true })
key("XF86AudioNext",  exec("playerctl next"), nil, { locked = true })
key("XF86AudioPrev",  exec("playerctl previous"), nil, { locked = true })
key("SUPER + SHIFT + P", exec("playerctl play-pause"), "Play / pause", { locked = true })
key("SUPER + SHIFT + N", exec("playerctl next"), "Next track", { locked = true })
key("SUPER + SHIFT + B", exec("playerctl previous"), "Previous track", { locked = true })
key("SUPER + M", global("lumen:island"), "Expand the island (media) — Esc closes")

-- ── Sidebar & notifications (same keys as ii) ──
group("Control centre")
key("SUPER + N", global("lumen:sidebar"), "Control centre & notifications")
key("SUPER + ALT + N", global("lumen:dnd"), "Focus (Do Not Disturb)")
key("SUPER + ALT + SHIFT + N", global("lumen:clearNotifications"), "Clear notifications")

-- ── Capture ──
group("Capture")
key("Print", exec(scripts .. "/screenshot.sh screen"), "Screenshot (screen)")
key("SUPER + SHIFT + S", exec(scripts .. "/screenshot.sh region"), "Screenshot (region)")
key("ALT + Print", exec(scripts .. "/screenshot.sh window"), "Screenshot (window)")
key("SUPER + SHIFT + E", exec(scripts .. "/screenshot.sh edit"), "Screenshot and annotate")
key("SUPER + SHIFT + T", exec(scripts .. "/screen-text.sh"), "Copy text from the screen (OCR)")
key("SUPER + SHIFT + C", exec("hyprpicker -a"), "Colour picker")
key("SUPER + SHIFT + R", exec(scripts .. "/screen-record.sh toggle region"), "Record a region (again: stop)", { locked = true })
key("CTRL + ALT + R", exec(scripts .. "/screen-record.sh toggle screen"), "Record the screen", { locked = true })
key("SUPER + SHIFT + ALT + R", exec(scripts .. "/screen-record.sh toggle screen --audio"), "Record the screen with sound", { locked = true })

-- ── Look ──
group("Look")
key("CTRL + SUPER + T", global("lumen:wallpapers"), "Wallpaper picker")
key("CTRL + SUPER + ALT + T", global("lumen:wallpaperRandom"), "Random wallpaper")
-- Zoom (accessibility): multiply / divide, never below 1×
local function zoom(f)
    return function()
        local z = hl.get_config("cursor.zoom_factor") or 1
        hl.config({ cursor = { zoom_factor = math.max(1, z * f) } })
    end
end
key("SUPER + Equal", zoom(1.25), "Zoom in", { repeating = true })
key("SUPER + Minus", zoom(1 / 1.25), "Zoom out", { repeating = true })

-- ── Session ──
group("Session")
key("SUPER + L", exec(ipc .. " lock lock || loginctl lock-session"), "Lock")
key("SUPER + SHIFT + L", exec("systemctl suspend"), "Sleep")
key("SUPER + Escape", global("lumen:powerMenu"), "Power menu")
key("CTRL + ALT + Delete", global("lumen:powerMenu"))
-- Emergency exit if the shell itself is broken (the power menu needs it)
key("CTRL + ALT + SHIFT + SUPER + Escape", hl.dsp.exit(), "Exit Hyprland (emergency)")
key("CTRL + SUPER + R", exec(bin .. "/lumen reload"), "Reload Lumen")
key("SUPER + Slash", global("lumen:cheatsheet"), "This cheatsheet")
