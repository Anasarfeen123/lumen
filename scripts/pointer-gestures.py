#!/usr/bin/env python3
"""pointer-gestures.py — gestures made with the pointer itself (mouse or touchpad).

  wiggle   shake the pointer quickly — side to side, up and down or in small circles
           (5 quick turns within 0.9 s, each a real swing, on either axis) → {"gesture": "wiggle"}
           Never while a button is held (dragging, selecting, drawing) or with two
           or more fingers on the touchpad (scrolling, gestures).
           (the shell makes the pointer big for a moment and rings close in on it)

Reads pointer devices only (their Handlers have "mouse" and not "kbd" — never a
keyboard), read-only and without grabbing them, so they work exactly as before.
You're in the `input` group. Devices plugged in later are picked up.

  pointer-gestures.py run [gentle|normal|firm]   (the shell runs it while Settings → Appearance → Shake to find is on)
  pointer-gestures.py devices  which devices it would read
"""
import json, os, re, select, struct, sys, time

EV_REL, EV_ABS, EV_KEY, EV_SYN = 0x02, 0x03, 0x01, 0x00
REL_X, REL_Y, ABS_X, ABS_Y, BTN_TOUCH = 0x00, 0x01, 0x00, 0x01, 0x14a
BUTTONS = range(0x110, 0x118)           # BTN_LEFT … BTN_TASK: held = a drag, never a shake
FMT = "llHHi"
SIZE = struct.calcsize(FMT)
# A shake is deliberate: 5 turns within 0.9 s, each a real swing (about a
# centimetre on a ~1000 DPI mouse) and each turn within 0.25 s of the last.
# (At first 4 turns of 45 counts — under a millimetre — so ordinary small
# corrections set it off.)
TURNS, WINDOW, GAP, COOLDOWN = 5, 0.9, 0.25, 2.0
BTN_TOOL_DOUBLETAP, BTN_TOOL_TRIPLETAP, BTN_TOOL_QUADTAP, BTN_TOOL_QUINTTAP = 0x14d, 0x14e, 0x14f, 0x148
# Settings → Appearance → Shake to find: how hard you have to shake (travel ×)
SENS = {"gentle": 0.6, "normal": 1.0, "firm": 1.6}


def devices():
    out = []
    for b in open("/proc/bus/input/devices").read().split("\n\n"):
        h = re.search(r"^H: Handlers=(.*)$", b, re.M)
        n = re.search(r'^N: Name="(.*)"$', b, re.M)
        if not h or "mouse" not in h.group(1) or "kbd" in h.group(1):
            continue
        ev = re.search(r"\bevent(\d+)\b", h.group(1))
        if ev:
            out.append(("/dev/input/event" + ev.group(1), n.group(1) if n else "", "touchpad" in (n.group(1).lower() if n else "")))
    return out


def abs_width(fd):
    import fcntl
    buf = bytearray(24)
    try:
        fcntl.ioctl(fd, 0x80184540 + ABS_X, buf)
        _, lo, hi = struct.unpack("iii", bytes(buf[:12]))
        return max(1, hi - lo)
    except OSError:
        return 1000


class Shake:
    """Counts direction reversals with real travel between them."""
    def __init__(self, travel):
        self.travel, self.dir, self.run, self.turns, self.last = travel, 0, 0, [], -1e9

    def feed(self, dx, now):
        if dx == 0:
            return False
        d = 1 if dx > 0 else -1
        if d == self.dir:
            self.run += abs(dx)
            return False
        # a turn — it counts only after a proper swing, soon after the last turn;
        # a small or slow one starts the count over
        if self.run >= self.travel and (not self.turns or now - self.turns[-1] <= GAP):
            self.turns = [t for t in self.turns if now - t < WINDOW] + [now]
        else:
            self.turns = [now] if self.run >= self.travel else []
        self.dir, self.run = d, abs(dx)
        if len(self.turns) >= TURNS and now - self.last > COOLDOWN:
            self.turns, self.last = [], now
            return True
        return False


def run(sens=1.0):
    fds = {}          # fd → (path, (shake_x, shake_y), is_touchpad, state)
    rescan_at = 0.0

    def rescan():
        known = {v[0] for v in fds.values()}
        for path, _, tp in devices():
            if path in known:
                continue
            try:
                fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
            except OSError:
                continue
            # mice: counts (DPI-dependent, ~ 40 per short swing); touchpads: 6 % of the pad
            travel = (abs_width(fd) * 0.12 if tp else 350) * sens
            fds[fd] = (path, (Shake(travel), Shake(travel)), tp, {"x": None, "y": None, "touch": False, "held": 0, "multi": 0})

    rescan()
    if not fds:
        print(json.dumps({"error": "No mouse or touchpad found."}), flush=True)
    while True:
        now = time.monotonic()
        if now > rescan_at:
            rescan(); rescan_at = now + 10
        r, _, _ = select.select(list(fds), [], [], 2)
        for fd in r:
            path, shake, tp, st = fds[fd]
            try:
                data = os.read(fd, SIZE * 128)
            except OSError:              # unplugged
                os.close(fd); del fds[fd]; continue
            dx = dy = 0
            for i in range(0, len(data) - SIZE + 1, SIZE):
                _, _, typ, code, val = struct.unpack(FMT, data[i:i + SIZE])
                if tp and typ == EV_KEY and code in (BTN_TOOL_DOUBLETAP, BTN_TOOL_TRIPLETAP, BTN_TOOL_QUADTAP, BTN_TOOL_QUINTTAP):
                    st["multi"] = max(0, st["multi"] + (1 if val else -1))     # two fingers or more: scrolling, a gesture
                elif typ == EV_KEY and code in BUTTONS:
                    st["held"] = max(0, st["held"] + (1 if val else -1))
                elif not tp and typ == EV_REL and code == REL_X:
                    dx += val
                elif not tp and typ == EV_REL and code == REL_Y:
                    dy += val
                elif tp and typ == EV_KEY and code == BTN_TOUCH:
                    st["touch"] = bool(val); st["x"] = st["y"] = None
                elif tp and typ == EV_ABS and code in (ABS_X, ABS_Y) and st["touch"]:
                    k = "x" if code == ABS_X else "y"
                    if st[k] is not None:
                        if k == "x": dx += val - st[k]
                        else: dy += val - st[k]
                    st[k] = val
            if st["held"] or st["multi"]:
                shake[0].turns = []; shake[1].turns = []      # a drag: start over after it
                continue
            now = time.monotonic()
            hit = (dx and shake[0].feed(dx, now)) or (dy and shake[1].feed(dy, now))
            if hit:
                shake[0].last = shake[1].last = now; shake[0].turns = []; shake[1].turns = []
                print(json.dumps({"gesture": "wiggle"}), flush=True)


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["devices"]:
        for d in devices():
            print("%s  %s%s" % (d[0], d[1], "  (touchpad)" if d[2] else ""))
    elif a[:1] == ["run"]:
        try:
            run(SENS.get(a[1] if len(a) > 1 else "normal", 1.0))
        except KeyboardInterrupt:
            pass
    else:
        print(__doc__); sys.exit(2)
