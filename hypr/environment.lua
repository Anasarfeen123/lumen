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

-- Qt theming is chosen by bin/lumen-session (qt6ct with Lumen colours when
-- installed, else KDE's platform theme); only set a default here.
if not os.getenv("QT_QPA_PLATFORMTHEME") then hl.env("QT_QPA_PLATFORMTHEME", "kde") end
hl.env("XDG_MENU_PREFIX", "plasma-")

-- Cursor
hl.env("XCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_SIZE", "24")
