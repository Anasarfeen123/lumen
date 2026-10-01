-- ── Input ────────────────────────────────────────────────────────────────────
hl.config({
    input = {
        kb_layout = "us",
        numlock_by_default = true,
        repeat_delay = 250,
        repeat_rate = 35,
        follow_mouse = LM.follow_mouse,        -- Lumen Settings → Windows
        off_window_axis_events = 2,
        touchpad = {
            natural_scroll = true,
            disable_while_typing = true,
            clickfinger_behavior = true,
            scroll_factor = 0.7,
        },
    },
    gestures = {
        workspace_swipe_distance = 700,
        workspace_swipe_cancel_ratio = 0.2,
        workspace_swipe_min_speed_to_force = 5,
        workspace_swipe_direction_lock = true,
        workspace_swipe_create_new = true,
    },
    binds = {
        -- One step per scroll gesture: touchpads and smooth-scrolling wheels send
        -- dozens of tiny events per swipe, each of which would switch a workspace
        scroll_event_delay = 120,
        hide_special_on_workspace_change = true,
        workspace_back_and_forth = false,
    },
})

-- Touchpad gestures (same grammar as the keys: a held key changes the meaning)
--   3 fingers, any direction    move the window under the fingers
--   3 fingers, pinch out / in   fullscreen / float or tile the window
--   4 fingers, left / right     previous / next workspace (follows your fingers)
--   4 fingers, up / down        open / close the overview
--   4 fingers, pinch in / out   minimise the window / show minimised windows
--   Alt + 3 fingers             resize the window under the fingers
--   Super + 3 fingers, pinch    zoom the screen (magnifier)
--   Super + 3 fingers, up/down  the scratchpad / the drop-down terminal
--   Super + 4 fingers, ← / →    workspaces that have windows only
-- (Hot corners — pointer into top-left / top-right — live in the shell.)
local function run(d) return function() hl.dispatch(d) end end
local function busy(step)                      -- next / previous workspace with windows (wraps)
    return function()
        local ids = {}
        for _, ws in ipairs(hl.get_workspaces()) do if ws.id > 0 and not ws.is_empty then ids[#ids + 1] = ws.id end end
        if #ids == 0 then return end
        table.sort(ids)
        local cur = hl.get_active_workspace()
        local here, target = cur and cur.id or ids[1], nil
        if step > 0 then for _, id in ipairs(ids) do if id > here then target = id; break end end; target = target or ids[1]
        else for k = #ids, 1, -1 do if ids[k] < here then target = ids[k]; break end end; target = target or ids[#ids] end
        hl.dispatch(hl.dsp.focus({ workspace = target }))
    end
end
hl.gesture({ fingers = 3, direction = "swipe", action = "move" })
hl.gesture({ fingers = 3, direction = "pinchout", action = "fullscreen" })
hl.gesture({ fingers = 3, direction = "pinchin", action = "float" })
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "up", action = function() hl.dispatch(hl.dsp.global("lumen:overviewOpen")) end })
hl.gesture({ fingers = 4, direction = "down", action = function() hl.dispatch(hl.dsp.global("lumen:overviewClose")) end })
hl.gesture({ fingers = 4, direction = "pinchin", action = run(hl.dsp.window.move({ workspace = "special:minimized", follow = false })) })
hl.gesture({ fingers = 4, direction = "pinchout", action = run(hl.dsp.workspace.toggle_special("minimized")) })
hl.gesture({ fingers = 3, direction = "swipe", mods = "ALT", action = "resize" })
hl.gesture({ fingers = 3, direction = "pinch", mods = "SUPER", action = "cursorZoom", zoom_level = 2 })
hl.gesture({ fingers = 3, direction = "up", mods = "SUPER", action = "special", workspace_name = "scratch" })
hl.gesture({ fingers = 3, direction = "down", mods = "SUPER", action = "special", workspace_name = "term" })
hl.gesture({ fingers = 4, direction = "left", mods = "SUPER", action = busy(-1) })
hl.gesture({ fingers = 4, direction = "right", mods = "SUPER", action = busy(1) })
