#!/usr/bin/env python3
"""touch-gestures.py — gestures Hyprland can't see, read from the touchpad.

  rest 3 fingers still (0.45 s)   circle to search
  rest 4 fingers still (0.45 s)   talk to Halo while they stay down; lift to send

Reads the touchpad's events read-only (you're in the `input` group; no grab, so
the touchpad works exactly as before). Only the touchpad device is opened, never
a keyboard. Swipes need movement, so they still belong to Hyprland.

  touch-gestures.py run        (the shell starts it when Settings → Halo → Touchpad gestures is on)
  touch-gestures.py device     which device it would read
Prints one JSON line per gesture: {"gesture": "circle"} · {"gesture": "talk", "state": "down"|"up"}.
"""
import json, os, re, select, struct, sys, time

EV_KEY, EV_ABS, EV_SYN = 0x01, 0x03, 0x00
BTN_TOUCH, BTN_TOOL_FINGER, BTN_TOOL_DOUBLETAP, BTN_TOOL_TRIPLETAP, BTN_TOOL_QUADTAP, BTN_TOOL_QUINTTAP = 0x14a, 0x145, 0x14d, 0x14e, 0x14f, 0x148
ABS_X, ABS_Y = 0x00, 0x01
FMT = "llHHi"
SIZE = struct.calcsize(FMT)
HOLD = 0.45            # seconds of rest
STILL = 0.035          # of the pad's width: more movement than this is a swipe, not a rest


def device():
    blocks = open("/proc/bus/input/devices").read().split("\n\n")
    for b in blocks:
        if re.search(r'^N: Name=".*touchpad.*"', b, re.I | re.M):
            m = re.search(r"\bevent(\d+)\b", b)
            if m:
                return "/dev/input/event" + m.group(1)
    return ""


def abs_range(fd, code):
    import fcntl
    buf = bytearray(24)
    try:
        fcntl.ioctl(fd, 0x80184540 + code, buf)      # EVIOCGABS(code)
        _, lo, hi = struct.unpack("iii", bytes(buf[:12]))
        return max(1, hi - lo)
    except OSError:
        return 1000


def out(o):
    print(json.dumps(o), flush=True)


def run():
    path = device()
    if not path:
        out({"error": "No touchpad found."}); return
    try:
        fd = os.open(path, os.O_RDONLY | os.O_NONBLOCK)
    except PermissionError:
        out({"error": "Can't read the touchpad (needs the input group)."}); return
    width = abs_range(fd, ABS_X)
    fingers, x, y = 0, None, None
    start = None              # (time, x, y) when this finger count began
    fired = None              # which gesture fired for this touch
    tools = {BTN_TOOL_FINGER: 1, BTN_TOOL_DOUBLETAP: 2, BTN_TOOL_TRIPLETAP: 3, BTN_TOOL_QUADTAP: 4, BTN_TOOL_QUINTTAP: 5}
    down = set()
    while True:
        r, _, _ = select.select([fd], [], [], 0.05)
        now = time.monotonic()
        if r:
            try:
                data = os.read(fd, SIZE * 64)
            except BlockingIOError:
                data = b""
            for i in range(0, len(data) - SIZE + 1, SIZE):
                _, _, typ, code, val = struct.unpack(FMT, data[i:i + SIZE])
                if typ == EV_KEY and code in tools:
                    (down.add if val else down.discard)(code)
                elif typ == EV_KEY and code == BTN_TOUCH and val == 0:
                    down.clear()
                elif typ == EV_ABS and code == ABS_X:
                    x = val
                elif typ == EV_ABS and code == ABS_Y:
                    y = val
                elif typ == EV_SYN:
                    n = max((tools[c] for c in down), default=0)
                    if n != fingers:
                        if fired == "talk":
                            out({"gesture": "talk", "state": "up"})
                        fired = None                         # a new finger count starts over
                        fingers = n
                        start = (now, x, y) if n in (3, 4) else None
                    elif start and x is not None and start[1] is not None and not fired:
                        if abs(x - start[1]) > STILL * width or abs((y or 0) - (start[2] or 0)) > STILL * width:
                            start = None                     # it moved: a swipe — Hyprland's
        if start and not fired and now - start[0] >= HOLD:
            if fingers == 3:
                fired = "circle"; out({"gesture": "circle"})
            elif fingers == 4:
                fired = "talk"; out({"gesture": "talk", "state": "down"})
            start = None


if __name__ == "__main__":
    a = sys.argv[1:]
    if a[:1] == ["device"]:
        print(device() or "none")
    elif a[:1] == ["run"]:
        try:
            run()
        except KeyboardInterrupt:
            pass
    else:
        print(__doc__); sys.exit(2)
