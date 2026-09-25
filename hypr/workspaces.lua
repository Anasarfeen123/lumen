-- ── Workspaces ───────────────────────────────────────────────────────────────
-- 1–10 are normal workspaces (created on demand). Special workspaces are
-- overlays that slide down over whatever you're doing:
--   special:scratch  Super+S           general scratchpad (send: Super+Alt+S)
--   special:term     Super+`           drop-down terminal (spawned on first use)
--   special:music    Super+Shift+`     music/media apps
hl.workspace_rule({ workspace = "special:scratch", gaps_out = 48 })
hl.workspace_rule({ workspace = "special:term", gaps_out = { top = 48, right = 160, bottom = 360, left = 160 }, on_created_empty = "kitty --class lumen-dropterm" })
hl.workspace_rule({ workspace = "special:music", gaps_out = { top = 48, right = 120, bottom = 48, left = 120 } })
