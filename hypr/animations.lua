-- ── Animations ───────────────────────────────────────────────────────────────
-- Durations (LM.t.*, Hyprland speed: 1 = 100 ms) and curves (lm_*) come from
-- theme/tokens.toml [motion]. DESIGN.md §7: exits faster than entries;
-- motion must explain something.
for name, points in pairs(LM.curves) do
    hl.curve("lm_" .. name, { type = "bezier", points = points })
end

local function anim(leaf, speed, curve, style)
    local a = { leaf = leaf, enabled = true, speed = speed, bezier = "lm_" .. curve }
    if style then a.style = style end
    hl.animation(a)
end

hl.config({ animations = { enabled = true } })

anim("global", LM.t.normal, "standard")

-- Windows: grow in from 86 % on a soft spring while fading; leave faster
anim("windowsIn", LM.t.large, "spring", "popin 86%")
anim("windowsOut", LM.t.window_exit, "accelerate", "popin 92%")
anim("windowsMove", LM.t.window, "emphasized", "slide")

-- Fades
anim("fadeIn", LM.t.window, "standard")
anim("fadeOut", LM.t.normal_exit, "accelerate")
anim("fadeSwitch", LM.t.micro, "standard")
anim("fadeShadow", LM.t.micro, "standard")
anim("fadeDim", LM.t.normal, "standard")

-- Border: colour cross-fade on focus; no spinning gradients
anim("border", LM.t.micro, "standard")
hl.animation({ leaf = "borderangle", enabled = false })

-- Layers (Lumen's own surfaces animate themselves; these cover third-party ones)
anim("layersIn", LM.t.normal, "standard", "popin 96%")
anim("layersOut", LM.t.normal_exit, "accelerate", "fade")
anim("fadeLayersIn", LM.t.normal, "standard")
anim("fadeLayersOut", LM.t.normal_exit, "accelerate")

-- Workspaces: a 12 % slide with a fade; scratchpads drop vertically
anim("workspaces", LM.t.large, "emphasized", "slidefade 12%")
anim("specialWorkspace", LM.t.window, "emphasized", "slidevert")

anim("zoomFactor", LM.t.normal, "standard")
