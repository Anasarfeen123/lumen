-- ── Startup ──────────────────────────────────────────────────────────────────
-- All autostart logic lives in bin/lumen-startup (readable, testable, and
-- guarded when Lumen runs nested for testing).
hl.on("hyprland.start", function()
    hl.exec_cmd(LUMEN_ROOT .. "/bin/lumen-startup")
end)
