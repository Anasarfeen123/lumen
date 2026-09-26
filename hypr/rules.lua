-- ── Window & layer rules ─────────────────────────────────────────────────────
local function rule(match, effects)
    effects.match = match
    hl.window_rule(effects)
end

-- ── Global behaviour ──
-- Tiled windows don't float, so they don't cast shadows (DESIGN.md §6.3)
rule({ float = false }, { no_shadow = true })
-- A lone tiled window needs no focus border: there is nothing to tell apart
rule({ float = false, workspace = "w[tv1]" }, { border_size = 0 })
-- XWayland drag/menus without a title or class: never blur or shadow them
rule({ class = "^()$", title = "^()$" }, { no_blur = true, no_shadow = true })

-- ── Dialogs & utilities float, centred ──
local dialogs = "^(Open File|Open Folder|Select a File|Save As|Save File|File Upload|Choose Files?)(.*)$"
rule({ title = dialogs }, { float = true, center = true, size = { "(monitor_w*0.6)", "(monitor_h*0.65)" } })
rule({ title = "^(.*)(wants to (save|open))$" }, { float = true })
local portal = "^(org\\.freedesktop\\.impl\\.portal\\.desktop\\.(kde|gtk|gnome))$"
rule({ class = portal }, { float = true, center = true, size = { "(monitor_w*0.6)", "(monitor_h*0.65)" } })

local mixer = "^(org\\.pulseaudio\\.pavucontrol|pavucontrol|pavucontrol-qt)$"
rule({ class = mixer }, { float = true, center = true, size = { "(monitor_w*0.45)", "(monitor_h*0.5)" } })
rule({ class = "^(nm-connection-editor|blueman-manager|\\.?blueberry.*|org\\.kde\\.bluedevilwizard)$" }, { float = true })
rule({ class = "^(kcm_.*|.*plasmawindowed.*|org\\.kde\\.polkit-kde-authentication-agent-1)$" }, { float = true })
rule({ class = "^(org\\.kde\\.polkit-kde-authentication-agent-1)$" }, { center = true })
rule({ class = "^(org\\.kde\\.ark|org\\.kde\\.kcalc|qalculate-gtk)$" }, { float = true })
rule({ title = "^(Copying|Moving|Deleting)(.*)(Dolphin)$" }, { float = true })

-- ── Lumen's own windows ──
-- Settings draws its own translucent background (compositor leaves it at 1.0);
-- Face ID setup is a small terminal.
rule({ title = "^(Lumen Settings)$" }, { float = true, center = true, size = { 1020, 760 }, opacity = "1.0 1.0" })
rule({ class = "^(lumen-faceid)$" }, { float = true, center = true, size = { 760, 520 } })

-- ── Picture-in-Picture: small, pinned, bottom-right ──
local pip = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$"
rule({ title = pip }, { float = true, pin = true, keep_aspect_ratio = true,
                        size = { "(monitor_w*0.25)", "(monitor_h*0.25)" }, move = { "(monitor_w*0.73)", "(monitor_h*0.72)" } })
-- Screen-share indicator popups: out of the way, bottom-centre
local sharing = ".*is sharing (a window|your screen).*"
rule({ title = sharing }, { float = true, pin = true, move = { "(monitor_w*0.5-window_w*0.5)", "(monitor_h-window_h-12)" } })

-- ── Window transparency (DESIGN.md §6.1) — toggle: Super+Shift+G ──
-- Order matters: later rules win. Every app → light frost; glass apps → more;
-- video, games and fullscreen → opaque.
local O = LM.opacity
local function opacity(a, i) return string.format("%s %s", a, i) end
rule({ class = ".*" }, { opacity = opacity(O.app_active, O.app_inactive) })
-- kitty draws its own translucent background (text stays crisp)
rule({ class = "^(kitty|lumen-dropterm)$" }, { opacity = "1.0 1.0" })
rule({ class = "^(foot)$" }, { opacity = opacity(O.terminal, O.terminal) })
rule({ class = "^(org\\.kde\\.dolphin|org\\.gnome\\.Nautilus|systemsettings|org\\.kde\\.systemsettings|org\\.pulseaudio\\.pavucontrol|pavucontrol|pavucontrol-qt|nm-connection-editor|org\\.kde\\.plasma-systemmonitor|org\\.gnome\\.SystemMonitor|org\\.kde\\.kcalc|qalculate-gtk|org\\.kde\\.ark|blueman-manager|nwg-look|org\\.kde\\.bluedevilwizard|kcm_.*)$" },
     { opacity = opacity(O.glass_active, O.glass_inactive) })
rule({ class = "^(mpv|vlc|io\\.github\\.celluloid_player\\.Celluloid|org\\.kde\\.haruna|steam_app_.*|gamescope|.*\\.exe)$" }, { opacity = "1.0 1.0" })
rule({ title = pip }, { opacity = "1.0 1.0" })
rule({ fullscreen = true }, { opaque = true })

-- ── Application workspaces (only apps that benefit from a fixed home) ──
rule({ class = "^(Spotify|spotify|com\\.spotify\\.Client)$" }, { workspace = "special:music silent" })
-- YouTube Music as a browser web app (Brave / Chrome / Chromium --app window)
rule({ class = "^(brave|chrome|chromium|google-chrome)-music\\.youtube\\.com.*$" }, { workspace = "special:music silent" })
rule({ class = "^(steam)$" }, { workspace = "9 silent" })

-- ── Games: tearing allowed; fullscreen keeps the screen awake ──
rule({ class = "^(steam_app_.*|gamescope)$" }, { immediate = true })
rule({ class = ".*" }, { idle_inhibit = "fullscreen" })

-- ── Layers ──
-- Lumen shell surfaces (lumen-*) animate themselves in QML — no compositor
-- animation; they share the glass blur; ignore_alpha keeps shadows unblurred.
hl.layer_rule({ match = { namespace = "^(lumen-.*)$" }, no_anim = true, blur = true, ignore_alpha = 0.3 })
-- …except the wallpaper: nothing sits behind it, so blurring it is pure cost
hl.layer_rule({ match = { namespace = "^(lumen-wallpaper)$" }, blur = false })
-- Pickers/selectors must appear instantly
hl.layer_rule({ match = { namespace = "^(hyprpicker|selection)$" }, no_anim = true })
