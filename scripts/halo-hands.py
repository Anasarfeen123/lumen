#!/usr/bin/env python3
"""halo-hands.py — Halo's hands: the pointer, clicks, the wheel and keys.

Everything here acts on THIS Hyprland session only, and only when the shell
asks (services/Hands.qml shows each click/type/key first and waits for your OK;
pointing and scrolling need no OK). Standard library only.

  halo-hands.py where                     JSON: {x, y} the pointer now (global layout px)
  halo-hands.py glide <x> <y> [ms]        move the pointer there smoothly (Hyprland's own
                                          cursor move); stops if you move the mouse yourself.
                                          JSON: {ok, x, y} or {ok: false, why: "you-moved"}
  halo-hands.py click <x> <y> [left|right|double]   glide there, then click (ydotool)
  halo-hands.py scroll <up|down> [steps]  the mouse wheel where the pointer is (ydotool)
  halo-hands.py key <combo>               e.g. ctrl+s, alt+Left, Return (wtype)
  halo-hands.py type <text>               types the text into the focused window (wtype)
  halo-hands.py read                      the text on the focused screen (tesseract), plain
  halo-hands.py a11y <name>               JSON: buttons/links named that, from apps' accessibility info
  halo-hands.py shot                      JSON: the focused screen as a small JPEG for a vision model
  halo-hands.py find <text>               JSON: where that text is (every screen, the focused one first),
                                          best match first [{x, y, w, h, text, score}]
                                          (grim + tesseract, on this computer; the
                                          picture is deleted at once)
"""
import json
import os
import re
import subprocess
import sys
import tempfile
import time

RUN = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
YDO = {**os.environ, "YDOTOOL_SOCKET": os.environ.get("YDOTOOL_SOCKET") or os.path.join(RUN, ".ydotool_socket")}


def out(o):
    sys.stdout.write(json.dumps(o) + "\n")
    sys.stdout.flush()


def hypr(*args):
    try:
        return subprocess.run(["hyprctl", *args], capture_output=True, text=True, timeout=2).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def where():
    m = re.match(r"\s*(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)", hypr("cursorpos"))
    return (float(m.group(1)), float(m.group(2))) if m else (0.0, 0.0)


def move(x, y):
    hypr("dispatch", "hl.dsp.cursor.move({ x = %d, y = %d })" % (round(x), round(y)))


def ease(t):        # in-out cubic
    return 4 * t * t * t if t < 0.5 else 1 - (-2 * t + 2) ** 3 / 2


def glide(x, y, ms=520):
    x0, y0 = where()
    dist = ((x - x0) ** 2 + (y - y0) ** 2) ** 0.5
    ms = max(180, min(int(ms), 300 + dist * 0.35))
    steps = max(6, int(ms / 16))
    last = (x0, y0)
    t0 = time.monotonic()
    for i in range(1, steps + 1):
        k = ease(i / steps)
        nx, ny = x0 + (x - x0) * k, y0 + (y - y0) * k
        if i % 4 == 0:
            cx, cy = where()
            if abs(cx - last[0]) > 24 or abs(cy - last[1]) > 24:      # you took the mouse
                return {"ok": False, "why": "you-moved", "x": cx, "y": cy}
        move(nx, ny)
        last = (round(nx), round(ny))
        lag = t0 + ms / 1000 * i / steps - time.monotonic()
        if lag > 0:
            time.sleep(lag)
    move(x, y)
    return {"ok": True, "x": x, "y": y}


def ydo(*args):
    try:
        r = subprocess.run(["ydotool", *args], env=YDO, capture_output=True, text=True, timeout=4)
        return r.returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def click(x, y, kind="left"):
    g = glide(x, y)
    if not g["ok"]:
        return g
    time.sleep(0.06)
    btn = "0xC1" if kind == "right" else "0xC0"
    ok = ydo("click", "-r", "2", "-D", "70", btn) if kind == "double" else ydo("click", btn)
    return {"ok": ok, "x": x, "y": y, "why": "" if ok else "ydotool isn't running (the ydotool service)"}


def scroll(direction, steps=5):
    n = max(1, min(30, int(steps)))
    return {"ok": ydo("mousemove", "--wheel", "-x", "0", "-y", str(n if direction == "up" else -n))}


KEYNAMES = {"enter": "Return", "return": "Return", "esc": "Escape", "escape": "Escape", "tab": "Tab", "space": "space",
            "backspace": "BackSpace", "delete": "Delete", "del": "Delete", "up": "Up", "down": "Down", "left": "Left",
            "right": "Right", "home": "Home", "end": "End", "pageup": "Prior", "pagedown": "Next", "pgup": "Prior", "pgdn": "Next"}
MODS = {"ctrl": "ctrl", "control": "ctrl", "alt": "alt", "shift": "shift", "super": "logo", "win": "logo", "meta": "logo"}


def key(combo):
    parts = [p.strip() for p in re.split(r"\s*\+\s*", combo.strip()) if p.strip()]
    if not parts:
        return {"ok": False, "why": "no key"}
    mods, k = [MODS.get(p.lower()) for p in parts[:-1]], parts[-1]
    if any(m is None for m in mods):
        return {"ok": False, "why": "unknown modifier"}
    name = KEYNAMES.get(k.lower(), k if len(k) > 1 else k.lower())
    if re.fullmatch(r"f\d{1,2}", k.lower()):
        name = k.upper()
    cmd = ["wtype"]
    for m in mods:
        cmd += ["-M", m]
    cmd += ["-k", name]
    for m in reversed(mods):
        cmd += ["-m", m]
    try:
        ok = subprocess.run(cmd, capture_output=True, timeout=4).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        ok = False
    return {"ok": ok}


def type_text(text):
    try:
        ok = subprocess.run(["wtype", "-d", "4", "--", text[:4000]], capture_output=True, timeout=60).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        ok = False
    return {"ok": ok}


def focused_monitor():
    try:
        for m in json.loads(hypr("-j", "monitors") or "[]"):
            if m.get("focused"):
                return m
    except ValueError:
        pass
    return None


def monitors():
    try:
        ms = [m for m in json.loads(hypr("-j", "monitors") or "[]") if not m.get("disabled")]
    except ValueError:
        return []
    return sorted(ms, key=lambda m: not m.get("focused"))       # the focused one first


ROLES = {"push button", "button", "toggle button", "link", "menu item", "page tab", "check box", "radio button", "combo box",
         "entry", "text", "icon", "list item", "tree item", "menu", "tool bar", "spin button", "slider", "label", "heading"}


def a11y(want, budget=3.0):
    """Buttons and links that apps describe by name (the accessibility bus) — icons included.
    Positions are window-relative on Wayland; Hyprland says where each window is."""
    try:
        import gi
        gi.require_version("Atspi", "2.0")
        from gi.repository import Atspi
    except (ImportError, ValueError):
        return []
    try:
        clients = json.loads(hypr("-j", "clients") or "[]")
        mons = monitors()
        active = {m["activeWorkspace"]["id"] for m in mons} | {m.get("specialWorkspace", {}).get("id") for m in mons if m.get("specialWorkspace", {}).get("id")}
    except (ValueError, KeyError):
        return []
    by_pid = {}

    def parent(pid):
        try:
            with open("/proc/%d/stat" % pid) as f:
                r = f.read()
            return int(r[r.rfind(")") + 2:].split()[1])
        except (OSError, ValueError, IndexError):
            return 0
    for c in clients:
        if c.get("workspace", {}).get("id") in active and not c.get("hidden") and c.get("mapped", True):
            # an app's accessibility may come from a wrapper process a few levels up
            p, hops = c["pid"], 0
            while p > 1 and hops < 4:
                by_pid.setdefault(p, c)
                p, hops = parent(p), hops + 1
    norm = lambda x: re.sub(r"[^a-z0-9 ]", "", x.lower()).strip()
    target = norm(want)
    if not target:
        return []
    t0, hits = time.monotonic(), []
    desk = Atspi.get_desktop(0)
    for i in range(desk.get_child_count()):
        app = desk.get_child_at_index(i)
        try:
            pid = app.get_process_id()
        except Exception:
            continue
        win = by_pid.get(pid)
        if not win:
            continue
        stack = [(app, 0)]
        while stack and time.monotonic() - t0 < budget:
            o, depth = stack.pop()
            try:
                name, role = o.get_name() or "", o.get_role_name()
                if name and role in ROLES:
                    n = norm(name)
                    score = 1.0 if n == target else 0.85 if n.startswith(target) or target in n.split() else 0.7 if target in n else 0
                    if score:
                        comp = o.get_component_iface()
                        e = comp.get_extents(Atspi.CoordType.WINDOW) if comp else None
                        if e and e.width > 0 and e.height > 0:
                            hits.append({"x": round(win["at"][0] + e.x + e.width / 2), "y": round(win["at"][1] + e.y + e.height / 2),
                                         "w": e.width, "h": e.height, "text": name, "score": score + (0.05 if role in ("push button", "button", "link") else 0)})
                if depth < 40:
                    for k in range(min(o.get_child_count(), 400)):
                        stack.append((o.get_child_at_index(k), depth + 1))
            except Exception:
                continue
    hits.sort(key=lambda h: -h["score"])
    return hits[:6]


def find(want):
    """Named buttons first (accessibility), then the text on every monitor (the focused one
    first); best match wins (ties: the focused screen)."""
    named = [h for h in a11y(want) if h["score"] >= 0.85]
    if named:
        return named
    hits = []
    for i, mon in enumerate(monitors()):
        for h in find_on(mon, want):
            h["score"] -= 0.001 * i
            hits.append(h)
        if any(h["score"] >= 0.99 for h in hits):
            break                                               # exact on the focused screen: enough
    hits.sort(key=lambda h: (-h["score"], h["y"], h["x"]))
    return hits[:6]


def shot():
    """The focused screen as a small JPEG for a vision model: {file, x, y, w, h} (logical px)."""
    mon = focused_monitor()
    if not mon:
        return {}
    scale = float(mon.get("scale") or 1)
    out = os.path.join(RUN, "lumen-ai", "halo-look-%d.jpg" % os.getpid())
    os.makedirs(os.path.dirname(out), mode=0o700, exist_ok=True)
    try:
        g = subprocess.Popen(["grim", "-o", mon["name"], "-"], stdout=subprocess.PIPE)
        subprocess.run(["magick", "-", "-resize", "1280x1280>", "-quality", "82", out], stdin=g.stdout, capture_output=True, timeout=10)
        g.wait(timeout=5)
    except (OSError, subprocess.TimeoutExpired):
        return {}
    return {"file": out, "x": mon["x"], "y": mon["y"], "w": round(mon["width"] / scale), "h": round(mon["height"] / scale)}


def find_on(mon, want):
    fd, img = tempfile.mkstemp(prefix="halo-find-", suffix=".png", dir=RUN)
    os.close(fd)
    try:
        if subprocess.run(["grim", "-o", mon["name"], img], capture_output=True, timeout=5).returncode != 0:
            return []
        tsv = subprocess.run(["tesseract", img, "-", "-l", "eng", "--psm", "11", "tsv"],
                             capture_output=True, text=True, timeout=30).stdout
    except (OSError, subprocess.TimeoutExpired):
        return []
    finally:
        try:
            os.remove(img)
        except OSError:
            pass
    words = []
    for line in tsv.splitlines()[1:]:
        f = line.split("\t")
        if len(f) < 12 or not f[11].strip():
            continue
        try:
            conf = float(f[10])
        except ValueError:
            continue
        if conf < 35:
            continue
        words.append({"t": f[11].strip(), "x": int(f[6]), "y": int(f[7]), "w": int(f[8]), "h": int(f[9]),
                      "key": (f[2], f[3], f[4])})
    norm = lambda s: re.sub(r"[^a-z0-9 ]", "", s.lower()).strip()
    target = norm(want).split()
    if not target:
        return []
    n = len(target)
    scale = float(mon.get("scale") or 1)
    hits = []
    # runs of n neighbouring words on one line, scored by how well they match
    for i in range(len(words)):
        run = words[i:i + n]
        if len(run) < n or any(r["key"] != run[0]["key"] for r in run):
            continue
        got = [norm(r["t"]) for r in run]
        exact = sum(1 for a, b in zip(got, target) if a == b)
        part = sum(1 for a, b in zip(got, target) if a != b and (b in a or (len(a) > 2 and a in b)))
        score = (exact + 0.6 * part) / n
        if score < 0.6:
            continue
        x0, y0 = min(r["x"] for r in run), min(r["y"] for r in run)
        x1, y1 = max(r["x"] + r["w"] for r in run), max(r["y"] + r["h"] for r in run)
        hits.append({"x": round(mon["x"] + (x0 + x1) / 2 / scale), "y": round(mon["y"] + (y0 + y1) / 2 / scale),
                     "w": round((x1 - x0) / scale), "h": round((y1 - y0) / scale),
                     "text": " ".join(r["t"] for r in run), "score": round(score, 2)})
    return hits


def read_screen():
    """All the text on the focused screen, top to bottom (for the agent)."""
    mon = focused_monitor()
    if not mon:
        return ""
    fd, img = tempfile.mkstemp(prefix="halo-read-", suffix=".png", dir=RUN)
    os.close(fd)
    try:
        if subprocess.run(["grim", "-o", mon["name"], img], capture_output=True, timeout=5).returncode != 0:
            return ""
        # larger and in greys reads far better (dark themes, small UI text)
        subprocess.run(["magick", img, "-colorspace", "Gray", "-resize", "160%", img], capture_output=True, timeout=10)
        return subprocess.run(["tesseract", img, "-", "-l", "eng", "--psm", "3"], capture_output=True, text=True, timeout=40).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""
    finally:
        try:
            os.remove(img)
        except OSError:
            pass


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        return
    c = a[0]
    if c == "where":
        x, y = where()
        out({"x": x, "y": y})
    elif c == "glide" and len(a) >= 3:
        out(glide(float(a[1]), float(a[2]), float(a[3]) if len(a) > 3 else 520))
    elif c == "click" and len(a) >= 3:
        out(click(float(a[1]), float(a[2]), a[3] if len(a) > 3 else "left"))
    elif c == "scroll" and len(a) >= 2:
        out(scroll(a[1], a[2] if len(a) > 2 else 5))
    elif c == "key" and len(a) >= 2:
        out(key(a[1]))
    elif c == "type" and len(a) >= 2:
        out(type_text(" ".join(a[1:])))
    elif c == "read":
        text = re.sub(r"\n{3,}", "\n\n", read_screen()).strip()
        sys.stdout.write(text[:8000] + "\n")
    elif c == "a11y" and len(a) >= 2:
        out(a11y(" ".join(a[1:])))
    elif c == "shot":
        out(shot())
    elif c == "find" and len(a) >= 2:
        out(find(" ".join(a[1:])))
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
