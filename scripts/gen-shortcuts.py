#!/usr/bin/env python3
"""Write docs/SHORTCUTS.md from the running Hyprland's binds (hyprctl binds -j).

Every bind in hypr/keybinds.lua carries a "Section: Label" description; this
groups them exactly like the in-desktop cheatsheet (Super+/). Run it inside a
Lumen session after changing keybinds:  scripts/gen-shortcuts.py
"""
import json, subprocess, sys
from pathlib import Path

NAMES = {"Return": "Enter", "grave": "`", "Semicolon": ";", "Apostrophe": "'", "Page_Up": "PgUp", "Page_Down": "PgDn",
         "mouse_down": "Scroll ↓", "mouse_up": "Scroll ↑", "mouse:272": "Drag", "mouse:273": "Right-drag",
         "mouse:275": "Back button", "mouse:276": "Forward button", "SUPER_L": "(tap)", "period": ".", "Equal": "=",
         "Minus": "−", "Space": "Space", "Escape": "Esc", "Delete": "Del", "Print": "PrtSc", "left": "←",
         "right": "→", "up": "↑", "down": "↓", "Tab": "Tab", "Slash": "/"}
GESTURES = [
    ("Tap Super", "Overview & search"), ("Top-left corner", "Overview & search"), ("Top-right corner", "Control centre"),
    ("4 fingers ↑ / ↓", "Open / close the overview"), ("4 fingers ← / →", "Switch workspace"),
    ("3 fingers drag", "Move a window"), ("3 fingers pinch", "Fullscreen"),
    ("Scroll on the bar", "Switch workspace"), ("Scroll on the island", "Volume (Shift: brightness)"),
    ("Right-click workspaces / island", "Apps in the background (tray)"), ("Middle-click the island", "Play / pause"),
    ("Click the island timer", "Pause / resume (right-click stops)"), ("Swipe a notification →", "Dismiss it"),
]

binds = json.loads(subprocess.run(["hyprctl", "-j", "binds"], capture_output=True, text=True, check=True).stdout)
order, groups = [], {}
for b in binds:
    desc = b.get("description") or ""
    if ": " not in desc:
        continue
    section, label = desc.split(": ", 1)
    m = b.get("modmask", 0)
    keys = [n for bit, n in ((64, "Super"), (4, "Ctrl"), (8, "Alt"), (1, "Shift")) if m & bit]
    k = NAMES.get(b["key"], b["key"].upper() if len(b["key"]) == 1 else b["key"])
    if "1…0" in label: k = "1…0"
    if "← → ↑ ↓" in label: k = "← → ↑ ↓"
    label = label.replace(" 1…0", "").replace(" ← → ↑ ↓", "")
    combo = "Tap <kbd>Super</kbd>" if b["key"] == "SUPER_L" else " + ".join(f"<kbd>{x}</kbd>" for x in keys + [k])
    if section not in groups:
        groups[section] = []; order.append(section)
    if not any(x[1] == label for x in groups[section]):
        groups[section].append((combo, label))

out = ["# Keyboard shortcuts & gestures", "",
       "> Generated from the live config by `scripts/gen-shortcuts.py`. In the desktop, press <kbd>Super</kbd> + <kbd>/</kbd> for the same list.", ""]
for s in order:
    out += [f"## {s}", "", "| Keys | Action |", "|---|---|"] + [f"| {k} | {l} |" for k, l in groups[s]] + [""]
out += ["## Gestures & mouse", "", "| Do | Action |", "|---|---|"] + [f"| {g} | {a} |" for g, a in GESTURES] + [""]
Path(__file__).resolve().parent.parent.joinpath("docs/SHORTCUTS.md").write_text("\n".join(out))
print(f"docs/SHORTCUTS.md: {sum(len(v) for v in groups.values())} shortcuts in {len(order)} sections")
