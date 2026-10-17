#!/usr/bin/env python3
"""scrollshot.py — a long screenshot of something you scroll (a page, a chat, a document).

  scrollshot.py <geometry> <out.png>     geometry as slurp prints it: "x,y wxh"

Captures the region a few times a second while YOU scroll (any speed, either
way); each frame is matched against the image so far by how far the content
moved, and only the new rows are added. Nothing scrolls by itself. Ends on
SIGTERM (Done in the island) or after 3 minutes / 40 000 rows; then writes the
PNG. Prints JSON lines: {"frames": n, "height": px} as it grows, then
{"done": true, "path": …, "height": …} (or {"error": …}).
"""
import io
import json
import os
import signal
import subprocess
import sys
import time

import numpy as np
from PIL import Image

MAX_ROWS = 40000
MAX_SECONDS = 180
DEBUG = bool(os.environ.get("SCROLLSHOT_DEBUG"))


def out(o):
    sys.stdout.write(json.dumps(o) + "\n")
    sys.stdout.flush()


def grab(geom):
    try:
        raw = subprocess.run(["grim", "-g", geom, "-t", "ppm", "-"], capture_output=True, timeout=5).stdout   # no compression: fast
        return Image.open(io.BytesIO(raw)).convert("RGB") if raw else None
    except (OSError, subprocess.TimeoutExpired, ValueError):
        return None


def gray(img, w=480):
    """Text edges (horizontal gradients) of a greyscale, narrower copy — every row
    kept so scrolled rows line up exactly; smooth backgrounds (a blurred wallpaper
    behind a translucent window, gradients) mostly vanish, so they can't mislead."""
    g = np.asarray(img.convert("L").resize((w, img.height), Image.BILINEAR), dtype=np.int16)
    return np.abs(np.diff(g, axis=1)), 1.0


def shift(prev, cur):
    """How many rows the content moved up from prev to cur: (dy, error).
    A cheap per-row profile shortlists offsets; the best few are checked
    pixel for pixel over the whole overlap (at least a quarter of the frame)."""
    h = prev.shape[0]
    lim = h - h // 4
    pa, pb = prev.mean(axis=1), cur.mean(axis=1)
    scores = np.array([np.abs(pa[dy:] - pb[:h - dy]).mean() for dy in range(lim)])
    best, err = 0, 1e9
    for dy in np.argsort(scores)[:12]:
        dy = int(dy)
        e = float(np.abs(prev[dy:] - cur[:h - dy]).mean())
        if e < err:
            best, err = dy, e
    return best, err


def main():
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(2)
    geom, path = sys.argv[1], sys.argv[2]
    stop = {"now": False}
    signal.signal(signal.SIGTERM, lambda *_: stop.update(now=True))
    signal.signal(signal.SIGINT, lambda *_: stop.update(now=True))
    first = grab(geom)
    if first is None:
        out({"error": "Couldn't capture that region."})
        return
    # Fixed bands (a page's header or toolbar, the window's own border) don't
    # scroll: they're kept once, and only the part between them is stitched.
    #   done: rows that have scrolled out of view (final) · current: the latest frame
    done, current = [], np.asarray(first)
    last_small, ratio = gray(first)
    top = bottom = 0
    frames, t0 = 1, time.monotonic()
    out({"frames": frames, "height": current.shape[0]})
    while not stop["now"] and time.monotonic() - t0 < MAX_SECONDS and sum(x.shape[0] for x in done) < MAX_ROWS:
        time.sleep(0.15)
        img = grab(geom)
        if img is None or img.size != first.size:
            continue
        small, _ = gray(img)
        if np.abs(small - last_small).mean() < 0.3:
            continue                                     # nothing moved
        # fixed bands: leading / trailing rows that didn't change (at most a quarter each)
        same = np.abs(small - last_small).mean(axis=1) < 0.5
        h = small.shape[0]
        t = int(np.argmin(same)) if not same.all() else 0
        b = int(np.argmin(same[::-1])) if not same.all() else 0
        t, b = min(t, h // 4), min(b, h // 4)
        dy, err = shift(last_small[t:h - b], small[t:h - b])
        if DEBUG:
            sys.stderr.write("dy=%d err=%.2f top=%d bottom=%d\n" % (dy, err, t, b))
        if err > 4:
            continue                                     # moved too far between frames: wait for a match
        if dy > 0:
            top, bottom = t, b
            done.append(current[top:top + dy])           # what scrolled off the top of the moving part is final
            frames += 1
        current = np.asarray(img)                        # in-place changes (and the rest) update the frame
        last_small = small
        out({"frames": frames, "height": sum(x.shape[0] for x in done) + current.shape[0]})
    strips = [current[:top]] + done + [current[top:]]
    canvas = np.concatenate(strips, axis=0)
    Image.fromarray(canvas).save(path, optimize=True)
    out({"done": True, "path": path, "height": int(canvas.shape[0])})


if __name__ == "__main__":
    main()
