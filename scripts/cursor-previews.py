#!/usr/bin/env python3
"""cursor-previews.py — the pointer themes installed here, with a preview of each.

  cursor-previews.py     JSON: [{id, name, preview}]; previews cached in
                         ~/.cache/lumen/cursors/<theme>.png (arrow and hand side by side)
Reads XCursor files directly (no tools needed); skips icon themes without cursors.
"""
import json, os, struct, sys, zlib

DIRS = [os.path.expanduser("~/.local/share/icons"), os.path.expanduser("~/.icons"), "/usr/share/icons"]
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache"), "lumen", "cursors")


def xcursor_image(path, want=48):
    """The image nearest `want` px from an XCursor file: (w, h, ARGB pixels)."""
    with open(path, "rb") as f:
        data = f.read()
    if data[:4] != b"Xcur":
        return None
    hsize, _, ntoc = struct.unpack_from("<III", data, 4)
    best = None
    for i in range(ntoc):
        typ, sub, pos = struct.unpack_from("<III", data, 16 + i * 12)
        if typ == 0xFFFD0002 and (best is None or abs(sub - want) < abs(best[0] - want)):
            best = (sub, pos)
    if not best:
        return None
    pos = best[1]
    w, h = struct.unpack_from("<II", data, pos + 16)
    px = struct.unpack_from("<%dI" % (w * h), data, pos + 36)
    return w, h, px


def png(path, w, h, rows):
    raw = b"".join(b"\x00" + bytes(r) for r in rows)
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xffffffff)
    with open(path, "wb") as f:
        f.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
                + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def preview(theme_dir, out):
    imgs = []
    for names in (("left_ptr", "default", "arrow"), ("hand2", "pointer", "pointing_hand", "hand1")):
        for n in names:
            p = os.path.join(theme_dir, "cursors", n)
            if os.path.exists(p):
                im = xcursor_image(os.path.realpath(p))
                if im:
                    imgs.append(im); break
    if not imgs:
        return False
    gap = 8
    W = sum(i[0] for i in imgs) + gap * (len(imgs) - 1); H = max(i[1] for i in imgs)
    canvas = [[0, 0, 0, 0] * W for _ in range(H)]
    x0 = 0
    for w, h, px in imgs:
        for y in range(h):
            row = canvas[y]
            for x in range(w):
                a = px[y * w + x]
                A, R, G, B = a >> 24, (a >> 16) & 255, (a >> 8) & 255, a & 255
                if A:     # XCursor is premultiplied
                    R, G, B = min(255, R * 255 // A), min(255, G * 255 // A), min(255, B * 255 // A)
                row[(x0 + x) * 4:(x0 + x) * 4 + 4] = [R, G, B, A]
        x0 += w + gap
    png(out, W, H, canvas)
    return True


def main():
    os.makedirs(CACHE, exist_ok=True)
    seen, out = set(), []
    for d in DIRS:
        if not os.path.isdir(d):
            continue
        for t in sorted(os.listdir(d)):
            td = os.path.join(d, t)
            if t in seen or not os.path.isdir(os.path.join(td, "cursors")):
                continue
            seen.add(t)
            name = t
            try:
                for line in open(os.path.join(td, "index.theme"), errors="replace"):
                    if line.startswith("Name="):
                        name = line[5:].strip(); break
            except OSError:
                pass
            pv = os.path.join(CACHE, t + ".png")
            src = os.path.join(td, "cursors", "left_ptr")
            fresh = os.path.exists(pv) and os.path.exists(src) and os.path.getmtime(pv) >= os.path.getmtime(os.path.realpath(src))
            if fresh or preview(td, pv):
                out.append({"id": t, "name": name, "preview": pv})
    print(json.dumps(out))


if __name__ == "__main__":
    main()
