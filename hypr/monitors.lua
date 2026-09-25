-- ── Monitors ─────────────────────────────────────────────────────────────────
-- Internal panel: 1920×1080 @ 144 Hz on the AMD iGPU.
hl.monitor({ output = "eDP-1", mode = "1920x1080@144", position = "0x0", scale = 1 })

-- Anything else (the HDMI port is wired to the NVIDIA dGPU): preferred mode,
-- placed automatically. Pin specific monitors in ~/.config/lumen/local.lua.
hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
