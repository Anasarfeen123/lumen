-- ── Environment ──────────────────────────────────────────────────────────────
-- GPU selection (AQ_DRM_DEVICES) is NOT set here: bin/lumen-session detects the
-- AMD iGPU / NVIDIA dGPU at login and exports it before Hyprland starts,
-- because /dev/dri/cardN numbering changes between boots.
-- Deliberately absent: GBM_BACKEND=nvidia-drm, __GLX_VENDOR_LIBRARY_NAME=nvidia,
-- LIBVA_DRIVER_NAME=nvidia (they force the dGPU on). One app on NVIDIA:
-- `lumen-dgpu <app>`.

hl.env("LUMEN", "1")

-- Session identity (portals, screen sharing, file pickers)
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")

-- Toolkits: prefer Wayland, fall back to X11
hl.env("GDK_BACKEND", "wayland,x11,*")
hl.env("QT_QPA_PLATFORM", "wayland;xcb")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("QT_AUTO_SCREEN_SCALE_FACTOR", "1")
hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")

-- Qt apps use KDE's platform theme (your Breeze colours, icons and fonts), so
-- they look the same here as in Plasma. (qt6ct with Lumen colours: DESIGN.md §23.)
if not os.getenv("QT_QPA_PLATFORMTHEME") then hl.env("QT_QPA_PLATFORMTHEME", "kde") end
hl.env("XDG_MENU_PREFIX", "plasma-")

-- With qt6ct (Lumen colours), KDE apps also get Lumen's colour scheme. The
-- generated dirs are searched *after* your own ~/.config and ~/.local/share,
-- so a scheme you pick in an app still wins, and kdeglobals is never touched.
if os.getenv("QT_QPA_PLATFORMTHEME") == "qt6ct" then
    local gen = (os.getenv("LUMEN_ROOT") or (os.getenv("HOME") .. "/.config/lumen")) .. "/generated"
    local function prepend(var, dir, default)
        local cur = os.getenv(var) or default
        if not cur:find(dir, 1, true) then hl.env(var, dir .. ":" .. cur) end
    end
    prepend("XDG_CONFIG_DIRS", gen .. "/xdg", "/etc/xdg")
    prepend("XDG_DATA_DIRS", gen .. "/share", "/usr/local/share:/usr/share")
    hl.env("KDE_COLOR_SCHEME_PATH", gen .. "/share/color-schemes/Lumen.colors")
end

-- Cursor (Lumen Settings → Appearance; default Bibata Modern Classic)
hl.env("XCURSOR_THEME", LM.cursor)
hl.env("XCURSOR_SIZE", tostring(LM.cursor_size))
hl.env("HYPRCURSOR_THEME", LM.cursor)
hl.env("HYPRCURSOR_SIZE", tostring(LM.cursor_size))
