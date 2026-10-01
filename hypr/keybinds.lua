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
local browser     = bin .. "/lumen-launch brave-origin brave-browser firefox chromium"
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
key("SUPER + SHIFT + Space", global("lumen:ai"), "Lumen Halo (AI)")
key("SUPER + SHIFT + W", global("lumen:inbox"), "Messages: reply, find a chat (WhatsApp)")

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
key("SUPER + ALT + P", hl.dsp.window.pin(), "Keep on all workspaces")
key("SUPER + U", hl.dsp.window.pseudo(), "Pseudo-tile")
key("SUPER + J", hl.dsp.layout("togglesplit"), "Flip split")
key("SUPER + ALT + Return", global("lumen:appMenu"), "Menu of the focused app")
key("SUPER + ALT + T", global("lumen:tray"), "Apps running in the background (tray)")
key("SUPER + SHIFT + G", exec(bin .. "/lumen transparency toggle"), "Window transparency on/off")
-- Caps Lock indicator: passes the key through, then the shell reads the LED
key("Caps_Lock", global("lumen:capsLock"), nil, { transparent = true, non_consuming = true, ignore_mods = true })

key("SUPER + left",  hl.dsp.focus({ direction = "left" }),  "Focus ← → ↑ ↓")
key("SUPER + right", hl.dsp.focus({ direction = "right" }))
key("SUPER + up",    hl.dsp.focus({ direction = "up" }))
key("SUPER + down",  hl.dsp.focus({ direction = "down" }))
key("SUPER + SHIFT + left",  hl.dsp.window.move({ direction = "left" }), "Move window ← → ↑ ↓")
key("SUPER + SHIFT + right", hl.dsp.window.move({ direction = "right" }))
key("SUPER + SHIFT + up",    hl.dsp.window.move({ direction = "up" }))
key("SUPER + SHIFT + down",  hl.dsp.window.move({ direction = "down" }))
key("CTRL + SUPER + SHIFT + right", hl.dsp.window.move({ workspace = "r+1", follow = true }), "Take window to next / previous workspace")
key("CTRL + SUPER + SHIFT + left",  hl.dsp.window.move({ workspace = "r-1", follow = true }))
key("CTRL + SUPER + SHIFT + up",    hl.dsp.window.move({ monitor = "u" }), "Send window to the monitor above / below")
key("CTRL + SUPER + SHIFT + down",  hl.dsp.window.move({ monitor = "d" }))
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
key("ALT + Tab", global("lumen:switcherNext"), "Switch windows (release Alt to pick)")
key("ALT + SHIFT + Tab", global("lumen:switcherPrev"))
key("ALT + grave", global("lumen:switcherApp"), "Switch between this app's windows")
-- Releasing Alt picks the window (transparent: the key still reaches apps)
key("ALT + ALT_L", global("lumen:switcherCommit"), nil, { release = true, transparent = true, ignore_mods = true })
key("ALT + ALT_R", global("lumen:switcherCommit"), nil, { release = true, transparent = true, ignore_mods = true })

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
-- Only workspaces that have windows, wrapping from the last back to the first
local function occupied(step)
    return function()
        local ids = {}
        for _, ws in ipairs(hl.get_workspaces()) do
            if ws.id > 0 and not ws.is_empty then ids[#ids + 1] = ws.id end
        end
        if #ids == 0 then return end
        table.sort(ids)
        local cur = hl.get_active_workspace()
        local here = cur and cur.id or ids[1]
        local target
        if step > 0 then
            for _, id in ipairs(ids) do if id > here then target = id; break end end
            target = target or ids[1]
        else
            for i = #ids, 1, -1 do if ids[i] < here then target = ids[i]; break end end
            target = target or ids[#ids]
        end
        hl.dispatch(hl.dsp.focus({ workspace = target }))
    end
end
key("CTRL + SUPER + ALT + right", occupied(1), "Next workspace with windows (wraps)")
key("CTRL + SUPER + ALT + left",  occupied(-1), "Previous workspace with windows (wraps)")
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
key("F12", hl.dsp.workspace.toggle_special("term"), "Drop-down terminal")
key("SUPER + grave", hl.dsp.workspace.toggle_special("term"))
key("SUPER + SHIFT + M", hl.dsp.workspace.toggle_special("music"), "Music scratchpad (opens your music app)")
key("SUPER + SHIFT + grave", hl.dsp.workspace.toggle_special("music"))

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

-- ── Laptop keys (Fn row, ASUS WMI hotkeys and friends) ──
-- Each one says what it did in the island (services/HwKeys.qml). Not bound
-- here on purpose: the sleep key (logind suspends, hypridle locks first) and
-- Fn+F5 on ASUS (the firmware switches the performance profile itself — the
-- island still shows the new mode). The power button opens the power menu:
-- Lumen holds logind's power-key inhibitor while it runs (bin/lumen-startup).
group("Laptop keys")
local hw = ipc .. " keys "
key("XF86RFKill", exec(hw .. "airplane"), "Airplane mode", { locked = true })
key("XF86WLAN", exec(hw .. "wifi"), nil, { locked = true })
key("XF86Bluetooth", exec(hw .. "bluetooth"), nil, { locked = true })
key("XF86TouchpadToggle", exec(hw .. "touchpad"), "Touchpad on / off", { locked = true })
key("CTRL + SUPER + F24", exec(hw .. "touchpad"), nil, { locked = true })   -- how many laptops send the touchpad key
key("XF86TouchpadOn", exec(hw .. "touchpadOn"), nil, { locked = true })
key("XF86TouchpadOff", exec(hw .. "touchpadOff"), nil, { locked = true })
key("XF86KbdBrightnessUp", exec(hw .. "kbdUp"), "Keyboard light up", lr)
key("XF86KbdBrightnessDown", exec(hw .. "kbdDown"), "Keyboard light down", lr)
key("XF86KbdLightOnOff", exec(hw .. "kbdCycle"), nil, { locked = true })
key("SUPER + P", exec(hw .. "display"), "Displays: extend · mirror · external only · laptop only")
key("XF86Display", exec(hw .. "display"), nil)
key("XF86Calculator", exec(hw .. "calculator"), "Calculator (the overview, ready for maths)")
key("XF86Launch3", exec(hw .. "performance"), "Power mode: balanced → performance → saver")
key("XF86Launch4", exec(hw .. "performance"), nil)
key("XF86Launch1", global("lumen:settings"), nil)
key("XF86PowerOff", exec(hw .. "power"), "Power menu")
key("XF86LogOff", exec(hw .. "power"), nil)
key("XF86ScreenSaver", exec(ipc .. " lock lock"), nil)
key("XF86WebCam", exec(hw .. "camera"), nil)
key("XF86AudioStop", exec("playerctl stop"), nil, { locked = true })
key("XF86AudioMedia", hl.dsp.workspace.toggle_special("music"), nil)
key("XF86WWW", exec(browser), nil)
key("XF86Mail", exec("xdg-open mailto:"), nil)
key("XF86Phone", exec(ipc .. " link ring"), nil)
key("XF86Tools", global("lumen:settings"), nil)

-- ── Sidebar & notifications (same keys as ii) ──
group("Control centre")
key("SUPER + N", global("lumen:sidebar"), "Notifications")
key("SUPER + A", global("lumen:controlCenter"), "Control centre")
key("SUPER + SHIFT + A", global("lumen:planner"), "Your day: weather, agenda, to-dos, notes")
key("SUPER + ALT + N", global("lumen:dnd"), "Focus (Do Not Disturb)")
key("CTRL + SUPER + N", global("lumen:focusCycle"), "Cycle Focus modes (Work, Game, Sleep …)")
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

-- ── Scroll & mouse: one grammar with the keyboard ──
-- Super moves you · +Shift carries the window · +Ctrl is the system
-- (volume, brightness) · +Alt is the finer variant. Up = previous / more.
group("Scroll & mouse")
local function both(mods, up, down, label)
    key(mods .. " + mouse_up", up, label)
    key(mods .. " + mouse_down", down, nil)
end
local function sh(cmd) return exec(cmd) end
both("SUPER + SHIFT", hl.dsp.window.move({ workspace = "r-1" }), hl.dsp.window.move({ workspace = "r+1" }),
     "Scroll: carry the window to the previous / next workspace")
both("CTRL + SUPER + ALT", occupied(-1), occupied(1), "Scroll: workspaces that have windows")
both("SUPER + ALT + SHIFT", hl.dsp.window.cycle_next({ next = false }), hl.dsp.window.cycle_next(),
     "Scroll: cycle through this workspace's windows")
both("CTRL + SUPER", sh("wpctl set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"), sh("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
     "Scroll: volume")
both("CTRL + SUPER + SHIFT", sh(ipc .. " brightness up"), sh(ipc .. " brightness down"), "Scroll: screen brightness")
both("SUPER + ALT", zoom(1.15), zoom(1 / 1.15), "Scroll: zoom in / out (magnifier)")
key("SUPER + mouse:274", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.center())
end, "Middle-click: float / tile the window")
key("CTRL + SUPER + mouse:274", exec("playerctl play-pause"), "Ctrl+middle-click: play / pause")

-- ── More windows & places ──
group("Windows")
key("SUPER + H", hl.dsp.window.move({ workspace = "special:minimized", follow = false }), "Minimise (tuck the window away)")
key("SUPER + SHIFT + H", hl.dsp.workspace.toggle_special("minimized"), "Show minimised windows")
key("SUPER + SHIFT + Return", hl.dsp.exec_cmd(terminal, { float = true, size = "1100 680", center = true }), "Floating terminal")
key("SUPER + SHIFT + F", function()
    hl.dispatch(hl.dsp.window.float({ action = "toggle" }))
    hl.dispatch(hl.dsp.window.resize({ x = 1280, y = 800, exact = true }))
    hl.dispatch(hl.dsp.window.center())
end, "Float, size and centre the window (focus it)")
key("SUPER + ALT + SHIFT + left",  hl.dsp.window.swap({ direction = "left" }), "Swap with the window to the left / right / up / down")
key("SUPER + ALT + SHIFT + right", hl.dsp.window.swap({ direction = "right" }))
key("SUPER + ALT + SHIFT + up",    hl.dsp.window.swap({ direction = "up" }))
key("SUPER + ALT + SHIFT + down",  hl.dsp.window.swap({ direction = "down" }))
key("SUPER + Home", function()
    local ids = {}
    for _, ws in ipairs(hl.get_workspaces()) do if ws.id > 0 and not ws.is_empty then ids[#ids + 1] = ws.id end end
    table.sort(ids)
    if #ids > 0 then hl.dispatch(hl.dsp.focus({ workspace = ids[1] })) end
end, "First workspace with windows")
key("SUPER + End", function()
    local ids = {}
    for _, ws in ipairs(hl.get_workspaces()) do if ws.id > 0 and not ws.is_empty then ids[#ids + 1] = ws.id end end
    table.sort(ids)
    if #ids > 0 then hl.dispatch(hl.dsp.focus({ workspace = ids[#ids] })) end
end, "Last workspace with windows")
key("SUPER + Backspace", hl.dsp.focus({ workspace = "previous" }), "Back to the last workspace")

group("Lumen")
key("SUPER + R", exec(ipc .. ' overview search ">"'), "Run a command (the overview, ready)")
key("SUPER + X", exec(ipc .. " dropzone toggle"), "Drop Zone shelf")
key("CTRL + SUPER + Space", exec(ipc .. ' ai ask "/screen"'), "Ask Halo about the screen")
key("SUPER + B", global("lumen:planner"), "Your day (planner)")
key("SUPER + comma", global("lumen:settings"))
key("CTRL + SUPER + W", exec(ipc .. " inbox shareClipboard"), "Send the clipboard to WhatsApp")


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
