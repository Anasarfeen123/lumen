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

-- Touchpad gestures
--   3 fingers, any direction  move the window under the fingers
--   3 fingers, pinch          toggle fullscreen
--   4 fingers, left / right   previous / next workspace (follows your fingers)
--   4 fingers, up / down      open / close the overview
-- (Hot corners — pointer into top-left / top-right — live in the shell.)
hl.gesture({ fingers = 3, direction = "swipe", action = "move" })
hl.gesture({ fingers = 3, direction = "pinch", action = "fullscreen" })
hl.gesture({ fingers = 4, direction = "horizontal", action = "workspace" })
hl.gesture({ fingers = 4, direction = "up", action = function() hl.dispatch(hl.dsp.global("lumen:overviewOpen")) end })
hl.gesture({ fingers = 4, direction = "down", action = function() hl.dispatch(hl.dsp.global("lumen:overviewClose")) end })
