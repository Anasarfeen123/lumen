#!/usr/bin/env python3
"""monitors.py — Lumen's screen layout (Settings → Display → Screens).

  monitors.py list            JSON: [{name, description, width, height, refresh, x, y, scale, modes:[…]}]
  monitors.py apply '<json>'  set it live: [{name, mode: "1920x1080@144", x, y, scale}]
  monitors.py save '<json>'   apply, and keep it: ~/.local/state/lumen/monitors.lua, which
                              hypr/hyprland.lua loads after its own monitors.lua (local.lua still wins)
  monitors.py forget          remove the saved layout (back to Lumen's defaults at the next reload)
"""
import json, os, re, subprocess, sys

STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "lumen")
SAVED = os.path.join(STATE, "monitors.lua")
SAFE = re.compile(r"^[A-Za-z0-9_.@x:-]+$")


def listing():
    mons = json.loads(subprocess.run(["hyprctl", "-j", "monitors", "all"], capture_output=True, text=True).stdout or "[]")
    out = []
    for m in mons:
        modes = []
        for s in m.get("availableModes", []):
            mm = re.match(r"(\d+)x(\d+)@([\d.]+)Hz", s)
            if mm:
                modes.append("%sx%s@%g" % (mm.group(1), mm.group(2), round(float(mm.group(3)), 2)))
        out.append({"name": m["name"], "description": m.get("description", ""), "width": m["width"], "height": m["height"],
                    "refresh": round(m.get("refreshRate", 60), 2), "x": m["x"], "y": m["y"], "scale": m.get("scale", 1),
                    "disabled": m.get("disabled", False), "modes": list(dict.fromkeys(modes))})
    return out


def lua(layout):
    lines = []
    for m in layout:
        name, mode = str(m["name"]), str(m["mode"])
        if not SAFE.match(name) or not SAFE.match(mode):
            raise SystemExit("bad monitor name or mode")
        scale = float(m.get("scale", 1))
        if not 0.5 <= scale <= 3:
            raise SystemExit("bad scale")
        lines.append('hl.monitor({ output = "%s", mode = "%s", position = "%dx%d", scale = %g })' % (name, mode, int(m["x"]), int(m["y"]), scale))
    return lines


def apply(layout):
    for line in lua(layout):
        r = subprocess.run(["hyprctl", "eval", line], capture_output=True, text=True)
        if r.returncode != 0:
            raise SystemExit(r.stdout + r.stderr)


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__); sys.exit(2)
    if a[0] == "list":
        print(json.dumps(listing()))
    elif a[0] in ("apply", "save") and len(a) > 1:
        layout = json.loads(a[1])
        apply(layout)
        if a[0] == "save":
            os.makedirs(STATE, exist_ok=True)
            with open(SAVED + ".tmp", "w") as f:
                f.write("-- Saved by Settings → Display → Screens (scripts/monitors.py). Delete to go back.\n" + "\n".join(lua(layout)) + "\n")
            os.replace(SAVED + ".tmp", SAVED)
        print(json.dumps({"ok": True}))
    elif a[0] == "forget":
        if os.path.exists(SAVED):
            os.unlink(SAVED)
        print(json.dumps({"ok": True}))
    else:
        print(__doc__); sys.exit(2)


if __name__ == "__main__":
    main()
