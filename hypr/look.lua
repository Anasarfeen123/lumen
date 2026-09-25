-- ── Look: geometry, borders, glass, shadows ─────────────────────────────────
-- Every value comes from a token (LM.*). DESIGN.md §5–§6.
hl.config({
    general = {
        layout = "dwindle",
        gaps_in = LM.gaps_in,
        gaps_out = LM.gaps_out,
        gaps_workspaces = 48,
        border_size = LM.border_size,
        col = {
            active_border = LM.accent_border,
            inactive_border = LM.border,
        },
        resize_on_border = true,
        extend_border_grab_area = 12,
        no_focus_fallback = true,
        allow_tearing = true,              -- only affects windows with the `immediate` rule
        snap = {
            enabled = true,
            window_gap = LM.gaps_in,
            monitor_gap = LM.gaps_out,
            respect_gaps = true,
        },
    },
    decoration = {
        rounding = LM.radius_window,
        rounding_power = LM.squircle,
        -- Opacity per app lives in rules.lua (glass apps, opaque video/games)
        active_opacity = 1.0,
        inactive_opacity = 1.0,
        fullscreen_opacity = 1.0,
        dim_special = 0.35,
        dim_around = 0.4,
        blur = {
            enabled = true,
            size = LM.blur.size,
            passes = LM.blur.passes,
            noise = LM.blur.noise,
            contrast = LM.blur.contrast,
            brightness = LM.blur.brightness,
            vibrancy = LM.blur.vibrancy,
            vibrancy_darkness = 0.0,
            new_optimizations = true,
            xray = false,                  -- glass shows what's really behind it
            special = true,                -- scratchpads float over a frosted desktop
            popups = true,                 -- context menus are frosted too
            popups_ignorealpha = 0.2,
        },
        -- Soft shadow, floating windows only (tiled get none — rules.lua)
        shadow = {
            enabled = true,
            range = LM.shadow_range,
            render_power = LM.shadow_power,
            color = LM.shadow,
            color_inactive = "rgba(00000033)",
            offset = "0 4",
        },
    },
    dwindle = {
        preserve_split = true,
        smart_split = false,
        force_split = 2,                   -- new window goes right / below
    },
    master = { new_status = "slave" },
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        background_color = LM.color.bg,
        force_default_wallpaper = 0,
        vrr = 2,                           -- adaptive sync in fullscreen only
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        animate_manual_resizes = false,
        animate_mouse_windowdragging = false,
        focus_on_activate = true,
        on_focus_under_fullscreen = 2,
        allow_session_lock_restore = true,
        initial_workspace_tracking = 0,
    },
    cursor = {
        inactive_timeout = 5,              -- hide the pointer while typing / idle
        hide_on_key_press = true,
    },
    ecosystem = {
        no_update_news = true,
        no_donation_nag = true,
    },
})
