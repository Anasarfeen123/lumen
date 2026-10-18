#!/usr/bin/env python3
"""pip.py — picture-in-picture for any window: a video, a player, a call.

  pip.py pop [address]          the window (default: the focused one) floats, pinned on
                                every workspace, small in a corner; its old place is kept
  pip.py back [address]         put it back exactly as it was (default: the PiP window)
  pip.py toggle                 pop the focused window, or put the PiP back
  pip.py corner <tl|tr|bl|br|next>   move the PiP window to a corner
  pip.py size <small|medium|large|bigger|smaller>
  pip.py state                  JSON: {address, title, class, corner, size} or {}
  pip.py video-rect <address> [x,y,w,h]   (optional: a screen area to ignore — Lumen's own PiP)
                                where the video is inside that window, from what moves over
                                ~0.6 s: {"x","y","w","h"} as fractions of the window, or {}
                                (paused, nothing moving, or the window isn't on screen)
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


def video_rect(addr, ignore=None):
    """The moving part of a visible window — the video in a browser tab. Six
    quick captures; pixels that change between them are the video. The longest
    run of busy columns, then of busy rows inside them, is its rectangle."""
    c = client(addr)
    if not c or c["size"][0] < 80 or c["size"][1] < 60:
        return {}
    ws = {m["activeWorkspace"]["id"] for m in (j("monitors") or [])}
    if c["workspace"]["id"] not in ws or c.get("hidden"):
        return {}
    try:
        import io, time
        import numpy as np
        from PIL import Image
    except ImportError:
        return {}
    geom = "%d,%d %dx%d" % (c["at"][0], c["at"][1], c["size"][0], c["size"][1])
    frames = []
    for i in range(6):
        raw = subprocess.run(["grim", "-g", geom, "-t", "ppm", "-"], capture_output=True, timeout=5).stdout
        if not raw:
            return {}
        im = Image.open(io.BytesIO(raw)).convert("L")
        W, H = im.size
        frames.append(np.asarray(im.resize((W // 4, H // 4)), dtype=np.int16))
        if i < 5:
            time.sleep(0.18)
    moved = np.zeros(frames[0].shape, dtype=bool)
    for a, b in zip(frames, frames[1:]):
        moved |= np.abs(a - b) > 10
    h, w = moved.shape
    # What covers the window moves too, and isn't its video: Lumen's own PiP
    # (passed in), and floating or pinned windows on top (a browser's PiP…)
    covers = [ignore] if ignore else []
    for o in j("clients") or []:
        if o["address"] != c["address"] and o.get("mapped", True) and not o.get("hidden") and o.get("floating") \
                and (o.get("pinned") or o["workspace"]["id"] == c["workspace"]["id"]):
            covers.append([o["at"][0], o["at"][1], o["size"][0], o["size"][1]])
    for ix, iy, iw, ih in covers:
        x0, y0 = max(0, (ix - c["at"][0]) // 4 - 2), max(0, (iy - c["at"][1]) // 4 - 2)
        x1, y1 = (ix + iw - c["at"][0]) // 4 + 2, (iy + ih - c["at"][1]) // 4 + 2
        if x1 > 0 and y1 > 0:
            moved[y0:y1, x0:x1] = False
    if moved.mean() < 0.01:
        return {}

    def run(profile, minimum, gap):
        """The longest stretch where profile >= minimum, bridging gaps up to `gap`."""
        on = [i for i, v in enumerate(profile) if v >= minimum]
        if not on:
            return 0, 0
        best, start, last = (on[0], on[0] + 1), on[0], on[0]
        for i in on[1:] + [None]:
            if i is not None and i - last <= gap:
                last = i
                continue
            if last + 1 - start > best[1] - best[0]:
                best = (start, last + 1)
            if i is not None:
                start = last = i
        return best

    c0, c1 = run(moved.mean(axis=0), 0.01, w // 12)
    r0, r1 = run(moved[:, c0:c1].mean(axis=1), 0.01, h // 12)
    if (c1 - c0) * (r1 - r0) < 0.04 * w * h or c1 - c0 < 20 or r1 - r0 < 12:
        return {}
    # Snap each side outwards to the video's edge: the nearest line (within a
    # little) where the picture changes sharply along most of that side.
    img = frames[-1]
    def edge_rows(lo, hi, cols):
        d = np.abs(np.diff(img[:, cols[0]:cols[1]], axis=0)) > 18      # between row i and i+1
        return d.mean(axis=1)
    def edge_cols(lo, hi, rows):
        d = np.abs(np.diff(img[rows[0]:rows[1], :], axis=1)) > 18
        return d.mean(axis=0)
    reach_y, reach_x = max(3, h // 4), max(3, w // 4)
    er = edge_rows(0, h, (c0, c1))
    top = [i + 1 for i in range(max(0, r0 - reach_y), r0) if er[i] > 0.6]
    bot = [i + 1 for i in range(r1 - 1, min(h - 1, r1 + reach_y)) if er[i] > 0.6]
    r0 = top[-1] if top else r0
    r1 = bot[0] if bot else r1
    ec = edge_cols(0, w, (r0, r1))
    left = [i + 1 for i in range(max(0, c0 - reach_x), c0) if ec[i] > 0.6]
    right = [i + 1 for i in range(c1 - 1, min(w - 1, c1 + reach_x)) if ec[i] > 0.6]
    c0 = left[-1] if left else c0
    c1 = right[0] if right else c1
    return {"x": round(c0 / w, 4), "y": round(r0 / h, 4), "w": round((c1 - c0) / w, 4), "h": round((r1 - r0) / h, 4)}


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
    elif cmd == "video-rect" and len(a) > 1:
        print(json.dumps(video_rect(a[1], [int(float(v)) for v in a[2].split(",")] if len(a) > 2 else None)))
    elif cmd == "state":
        print(json.dumps(current()))
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
