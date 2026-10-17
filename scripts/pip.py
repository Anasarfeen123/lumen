#!/usr/bin/env python3
"""pip.py — picture-in-picture for any window: a video, a player, a call.

  pip.py pop [address]          the window (default: the focused one) floats, pinned on
                                every workspace, small in a corner; its old place is kept
  pip.py back [address]         put it back exactly as it was (default: the PiP window)
  pip.py toggle                 pop the focused window, or put the PiP back
  pip.py corner <tl|tr|bl|br|next>   move the PiP window to a corner
  pip.py size <small|medium|large|bigger|smaller>
  pip.py state                  JSON: {address, title, class, corner, size} or {}
Browser picture-in-picture windows are already floated and pinned by
hypr/rules.lua; this works on them too (corners, sizes). State lives in
$XDG_RUNTIME_DIR/lumen-pip.json for this session only.
"""
import json
import os
import subprocess
import sys

STATE = os.path.join(os.environ.get("XDG_RUNTIME_DIR") or "/tmp", "lumen-pip.json")
SIZES = {"small": 0.22, "medium": 0.3, "large": 0.42}
MARGIN = 18


def hypr(*a):
    try:
        return subprocess.run(["hyprctl", *a], capture_output=True, text=True, timeout=3).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def j(*a):
    try:
        return json.loads(hypr("-j", *a) or "null")
    except ValueError:
        return None


def do(*cmds):
    for c in cmds:
        hypr("dispatch", c)


def load():
    try:
        with open(STATE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save(s):
    with open(STATE, "w") as f:
        json.dump(s, f)


def client(addr):
    return next((c for c in (j("clients") or []) if c["address"] == addr), None)


def monitor_of(c):
    mons = j("monitors") or []
    return next((m for m in mons if m["id"] == c["monitor"]), mons[0] if mons else None)


def place(c, corner, frac):
    m = monitor_of(c)
    if not m:
        return
    scale = float(m.get("scale") or 1)
    mw, mh = m["width"] / scale, m["height"] / scale
    res = m.get("reserved") or [0, 0, 0, 0]          # left, top, right, bottom
    aspect = (c["size"][0] / c["size"][1]) if c["size"][1] else 16 / 9
    aspect = min(max(aspect, 0.5), 2.4)
    w = round(mw * frac)
    h = round(w / aspect)
    if h > mh * 0.6:
        h = round(mh * 0.6)
        w = round(h * aspect)
    left = m["x"] + res[0] + MARGIN
    right = m["x"] + mw - res[2] - MARGIN - w
    top = m["y"] + res[1] + MARGIN
    bottom = m["y"] + mh - res[3] - MARGIN - h
    x = left if corner in ("tl", "bl") else right
    y = top if corner in ("tl", "tr") else bottom
    do('hl.dsp.focus({ window = "address:%s" })' % c["address"],
       'hl.dsp.window.resize({ x = %d, y = %d, relative = false })' % (w, h),
       'hl.dsp.window.move({ x = %d, y = %d, relative = false })' % (x, y),
       'hl.dsp.window.alter_zorder({ mode = "top" })')


def pop(addr=None):
    c = client(addr) if addr else j("activewindow")
    if not c or not c.get("address"):
        return {"ok": False, "error": "No window to pop out."}
    c = client(c["address"])
    s = load()
    if s.get("address") and s["address"] != c["address"] and client(s["address"]):
        back(s["address"])                              # one PiP at a time
    s = {"address": c["address"], "title": c["title"], "class": c["class"], "corner": "br", "size": "small",
         "was": {"floating": c["floating"], "pinned": c["pinned"], "at": c["at"], "size": c["size"], "workspace": c["workspace"]["id"]}}
    do('hl.dsp.focus({ window = "address:%s" })' % c["address"],
       'hl.dsp.window.float({ action = "enable" })',
       'hl.dsp.window.pin({ action = "enable" })')
    c = client(c["address"]) or c
    place(c, "br", SIZES["small"])
    save(s)
    return {"ok": True, "title": c["title"]}


def back(addr=None):
    s = load()
    a = addr or s.get("address")
    c = client(a) if a else None
    if not c:
        save({})
        return {"ok": False, "error": "No picture-in-picture window."}
    was = s.get("was") if s.get("address") == a else None
    cmds = ['hl.dsp.focus({ window = "address:%s" })' % a, 'hl.dsp.window.pin({ action = "disable" })']
    if was:
        if was["floating"]:
            cmds += ['hl.dsp.window.resize({ x = %d, y = %d, relative = false })' % tuple(was["size"]),
                     'hl.dsp.window.move({ x = %d, y = %d, relative = false })' % tuple(was["at"])]
        else:
            cmds += ['hl.dsp.window.float({ action = "disable" })']
        cmds += ['hl.dsp.window.move({ workspace = %d, follow = true })' % was["workspace"]] if was["workspace"] > 0 else []
    do(*cmds)
    save({})
    return {"ok": True}


def current():
    s = load()
    if s.get("address") and client(s["address"]):
        return s
    # a browser's own PiP window counts too
    for c in j("clients") or []:
        if c.get("pinned") and c.get("floating") and "picture" in c["title"].lower():
            return {"address": c["address"], "title": c["title"], "class": c["class"], "corner": "br", "size": "small", "browser": True}
    return {}


def main():
    a = sys.argv[1:]
    cmd = a[0] if a else "state"
    if cmd == "pop":
        print(json.dumps(pop(a[1] if len(a) > 1 else None)))
    elif cmd == "back":
        print(json.dumps(back(a[1] if len(a) > 1 else None)))
    elif cmd == "toggle":
        print(json.dumps(back() if current().get("address") and not current().get("browser") else pop()))
    elif cmd in ("corner", "size") and len(a) > 1:
        s = current()
        c = client(s.get("address", "")) if s else None
        if not c:
            print(json.dumps({"ok": False, "error": "No picture-in-picture window."}))
            return
        order = ["br", "bl", "tl", "tr"]
        if cmd == "corner":
            s["corner"] = order[(order.index(s.get("corner", "br")) + 1) % 4] if a[1] == "next" else a[1]
        else:
            names = list(SIZES)
            i = names.index(s.get("size", "small"))
            s["size"] = names[min(i + 1, 2)] if a[1] == "bigger" else names[max(i - 1, 0)] if a[1] == "smaller" else a[1] if a[1] in SIZES else s["size"]
        place(c, s["corner"], SIZES[s["size"]])
        if not s.get("browser"):
            save(s)
        print(json.dumps({"ok": True, "corner": s["corner"], "size": s["size"]}))
    elif cmd == "state":
        print(json.dumps(current()))
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
