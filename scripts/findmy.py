#!/usr/bin/env python3
"""Find my laptop — Lumen's remote for a lost or stolen laptop.

The laptop listens on a private ntfy channel (ntfy.sh by default: a free public
relay). The channel's name is a long random secret, and every message both ways
is sealed with AES-256-GCM under a random key that only this laptop and your
phone's remote page hold — the relay only ever carries ciphertext, and a message
that doesn't open with the key is ignored, so knowing the channel name isn't
enough to send the laptop anything.

From the remote (a web page Lumen sends to your phone, `remote`):
  ring [message]      a loud alarm through the laptop's own speakers, the screen
                      saying it's lost (Lumen draws it; scripts can't)
  stop                stop ringing
  lock                lock the screen and turn on lost mode
  lost on|off         lost mode: your message and number on the lock screen, and
                      a location report every 15 minutes while it's on
  locate              where it is: nearby Wi-Fi networks → BeaconDB (an open
                      location database), the network it's on, battery
  photo               one webcam picture (its light comes on)
  screen              a screenshot
  status              battery, network, uptime
Nothing is located, photographed or sent except when the remote asks (or lost
mode's 15-minute report).

  findmy.py setup [--rotate]    make (or replace) the channel and key
  findmy.py info                what's set up (no secrets)
  findmy.py remote              write the phone page, print its path
  findmy.py lost on|off [message] [phone]
  findmy.py serve               run (Lumen's shell starts this); prints the
                                things only Lumen can do as JSON lines:
                                {"do": "ring"|"stop"|"lock"|"lost", …}
  findmy.py gather locate|status|photo|screen    try one locally (prints JSON)

Files: ~/.local/state/lumen/findmy.json (the key; 0600), findmy-lost.json (lost
mode, for the lock screen), findmy-remote.html (0600; the phone page, key inside).
"""
import base64
import glob
import json
import os
import secrets
import shutil
import socket
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.request

try:
    from cryptography.hazmat.primitives.ciphers.aead import AESGCM
except ImportError:                      # Fedora: sudo dnf install python3-cryptography
    print(json.dumps({"ok": False, "error": "needs python3-cryptography (sudo dnf install python3-cryptography)"}), flush=True)
    sys.exit(3)

HERE = os.path.dirname(os.path.realpath(__file__))
STATE_DIR = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "lumen")
CONF = os.path.join(STATE_DIR, "findmy.json")
LOST = os.path.join(STATE_DIR, "findmy-lost.json")
REMOTE = os.path.join(STATE_DIR, "findmy-remote.html")
AAD = b"lumen-findmy-v1"
UA = "lumen-findmy/1"
SERVER = "https://ntfy.sh"
LOST_EVERY = 15 * 60          # seconds between lost-mode reports
RING_MAX_AGE = 10 * 60        # an older "ring" (sent while the laptop was offline) is skipped
CMD_MAX_AGE = 12 * 3600       # ntfy.sh keeps messages about 12 hours


def out(o):
    print(json.dumps(o), flush=True)


def write_private(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".findmy-")
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(data if isinstance(data, str) else json.dumps(data, indent=1))
        os.replace(tmp, path)
    except BaseException:
        try:
            os.unlink(tmp)
        except OSError:
            pass
        raise


def read_json(path, default=None):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def conf():
    c = read_json(CONF)
    if not c or not c.get("topic") or not c.get("key"):
        return None
    return c


# ── sealing ──
def b64u(b):
    return base64.urlsafe_b64encode(b).rstrip(b"=").decode()


def unb64u(s):
    return base64.urlsafe_b64decode(s + "=" * (-len(s) % 4))


def seal(key, obj):
    nonce = os.urandom(12)
    return "lm1." + b64u(nonce + AESGCM(key).encrypt(nonce, json.dumps(obj).encode(), AAD))


def seal_bytes(key, data):
    nonce = os.urandom(12)
    return nonce + AESGCM(key).encrypt(nonce, data, AAD)


def unseal(key, text):
    if not isinstance(text, str) or not text.startswith("lm1."):
        return None
    try:
        raw = unb64u(text[4:])
        return json.loads(AESGCM(key).decrypt(raw[:12], raw[12:], AAD))
    except Exception:
        return None


# ── the relay ──
def publish(c, obj, attachment=None):
    key = unb64u(c["key"])
    url = c.get("server", SERVER).rstrip("/") + "/" + c["topic"]
    body = seal(key, dict(obj, frm="laptop", t=int(time.time())))
    if attachment is None:
        req = urllib.request.Request(url, data=body.encode(), method="POST", headers={"User-Agent": UA})
    else:
        # the file goes up sealed; the message (also sealed) says what it is
        req = urllib.request.Request(url, data=seal_bytes(key, attachment), method="PUT",
                                     headers={"User-Agent": UA, "Filename": "lumen.bin", "Message": body})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read() or b"{}")


# ── what the laptop can tell ──
def run(cmd, timeout=20):
    try:
        return subprocess.run(cmd, capture_output=True, text=True, timeout=timeout).stdout
    except (OSError, subprocess.TimeoutExpired):
        return ""


def battery():
    for b in sorted(glob.glob("/sys/class/power_supply/BAT*")):
        try:
            cap = int(open(b + "/capacity").read().strip())
            st = open(b + "/status").read().strip()
            return {"percent": cap, "state": st}
        except (OSError, ValueError):
            pass
    return None


def network():
    active = [l.split(":", 1)[1] for l in run(["nmcli", "-t", "-f", "ACTIVE,SSID", "dev", "wifi"]).splitlines() if l.startswith("yes:")]
    conns = [l for l in run(["nmcli", "-t", "-f", "TYPE,STATE,CONNECTION", "dev"]).splitlines() if ":connected:" in l]
    return {"wifi": active[0] if active else "", "connections": [l.split(":", 2)[2] for l in conns][:4]}


def status():
    up = float(open("/proc/uptime").read().split()[0]) if os.path.exists("/proc/uptime") else 0
    return {"host": socket.gethostname(), "battery": battery(), "network": network(), "uptimeMin": int(up // 60),
            "lost": (read_json(LOST, {}) or {}).get("on", False)}


def wifi_aps():
    aps = []
    for line in run(["nmcli", "-t", "-f", "BSSID,SIGNAL", "dev", "wifi", "list", "--rescan", "auto"], timeout=30).splitlines():
        # BSSID colons are escaped: AA\:BB\:…:75
        parts = line.replace("\\:", "-").split(":")
        if len(parts) >= 2 and parts[1].isdigit():
            aps.append({"macAddress": parts[0].replace("-", ":").lower(), "signalStrength": int(parts[1]) // 2 - 100})
    return aps[:30]


def locate():
    aps = wifi_aps()
    loc = None
    err = ""
    if aps:
        try:
            req = urllib.request.Request("https://api.beacondb.net/v1/geolocate", method="POST",
                                         data=json.dumps({"considerIp": True, "wifiAccessPoints": aps}).encode(),
                                         headers={"User-Agent": UA, "Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=30) as r:
                d = json.loads(r.read())
            if d.get("location"):
                loc = {"lat": d["location"]["lat"], "lng": d["location"]["lng"], "accuracy": round(d.get("accuracy") or 0)}
        except (urllib.error.URLError, TimeoutError, OSError, ValueError, KeyError) as e:
            err = "location service: %s" % getattr(e, "reason", e)
    else:
        err = "no Wi-Fi networks in range (Wi-Fi off?)"
    return dict(status(), location=loc, wifiSeen=len(aps), error=err)


def photo():
    if not shutil.which("ffmpeg"):
        return None, "ffmpeg isn't installed"
    devs = sorted(glob.glob("/dev/video*"))
    if not devs:
        return None, "no camera"
    with tempfile.TemporaryDirectory() as d:
        f = os.path.join(d, "p.jpg")
        for dev in devs[:2]:
            # skip the first frames: the camera adjusts to the light
            subprocess.run(["ffmpeg", "-loglevel", "error", "-f", "v4l2", "-i", dev, "-vf", "select=gte(n\\,15),scale=960:-2",
                            "-frames:v", "1", "-q:v", "6", "-y", f], capture_output=True, timeout=25)
            if os.path.exists(f) and os.path.getsize(f) > 2000:
                return open(f, "rb").read(), ""
    return None, "the camera didn't give a picture (in use?)"


def screen():
    if not shutil.which("grim"):
        return None, "grim isn't installed"
    with tempfile.TemporaryDirectory() as d:
        f = os.path.join(d, "s.jpg")
        subprocess.run(["grim", "-s", "0.5", "-t", "jpeg", "-q", "60", f], capture_output=True, timeout=20)
        if os.path.exists(f) and os.path.getsize(f) > 2000:
            return open(f, "rb").read(), ""
    return None, "couldn't take a screenshot"


# ── lost mode ──
def set_lost(on, message="", phone=""):
    cur = read_json(LOST, {}) or {}
    st = {"on": bool(on), "message": message or cur.get("message", ""), "phone": phone or cur.get("phone", ""),
          "since": int(time.time()) if on and not cur.get("on") else cur.get("since", 0) if on else 0}
    write_private(LOST, st)
    os.chmod(LOST, 0o644)        # the lock screen reads it; it holds nothing secret
    return st


# ── commands from the remote ──
def handle(c, cmd, seen):
    if not isinstance(cmd, dict) or cmd.get("frm") != "phone":
        return
    cid, age = cmd.get("id", ""), time.time() - (cmd.get("t") or 0)
    if not cid or cid in seen or age > CMD_MAX_AGE or age < -600:
        return
    seen.append(cid)
    del seen[:-200]
    what, args = cmd.get("cmd", ""), cmd.get("args") or {}
    reply = {"re": cid, "cmd": what}
    if what == "ring":
        if age > RING_MAX_AGE:
            return publish(c, dict(reply, ok=False, note="That ring was sent %d min ago, while the laptop was offline — skipped." % (age // 60)))
        out({"do": "ring", "message": str(args.get("message", ""))[:200]})
        publish(c, dict(reply, ok=True, note="Ringing"))
    elif what == "stop":
        out({"do": "stop"})
        publish(c, dict(reply, ok=True, note="Stopped"))
    elif what in ("lock", "lost"):
        on = what == "lock" or str(args.get("on", "on")) == "on"
        st = set_lost(on, str(args.get("message", ""))[:300], str(args.get("phone", ""))[:40])
        out({"do": "lost", "on": on})
        if what == "lock":
            out({"do": "lock"})
        publish(c, dict(reply, ok=True, lost=st["on"], note="Locked, lost mode on" if what == "lock" else ("Lost mode on" if on else "Lost mode off")))
        if on:
            publish(c, dict(locate(), re=cid, cmd="locate", ok=True))
    elif what == "locate":
        publish(c, dict(locate(), **reply, ok=True))
    elif what == "status":
        publish(c, dict(status(), **reply, ok=True))
    elif what in ("photo", "screen"):
        data, err = photo() if what == "photo" else screen()
        if data:
            publish(c, dict(reply, ok=True, kind="image/jpeg", bytes=len(data)), attachment=data)
        else:
            publish(c, dict(reply, ok=False, note=err))
    else:
        publish(c, dict(reply, ok=False, note="Unknown command"))


def serve():
    c = conf()
    if not c:
        out({"error": "not set up"})
        return 1
    key = unb64u(c["key"])
    seen = c.get("seen", [])
    since = c.get("since") or "1h"
    url_base = c.get("server", SERVER).rstrip("/") + "/" + c["topic"] + "/json"
    last_report = 0
    backoff = 5
    out({"event": "listening"})
    while True:
        try:
            req = urllib.request.Request(url_base + "?since=" + since, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=90) as r:
                backoff = 5
                for raw in r:
                    m = json.loads(raw or b"{}")
                    if m.get("event") == "message":
                        since = m.get("id") or since
                        cmd = unseal(key, m.get("message", ""))
                        handle(c, cmd, seen)
                        c2 = read_json(CONF, {}) or {}
                        if c2.get("key") != c["key"]:           # keys rotated: start over
                            return 0
                        c2.update({"since": since, "seen": seen})
                        write_private(CONF, c2)
                    # lost mode: a report every 15 minutes (between messages; ntfy sends keepalives)
                    lost = read_json(LOST, {}) or {}
                    if lost.get("on") and time.time() - last_report > LOST_EVERY:
                        last_report = time.time()
                        try:
                            publish(c, dict(locate(), cmd="report", ok=True, note="Lost mode report"))
                        except (urllib.error.URLError, TimeoutError, OSError):
                            pass
        except (urllib.error.URLError, TimeoutError, OSError, ValueError) as e:
            out({"event": "offline", "error": str(getattr(e, "reason", e))[:120]})
            time.sleep(backoff)
            backoff = min(300, backoff * 2)


# ── setup and the phone page ──
def setup(rotate=False):
    c = conf()
    if c and not rotate:
        return out(info())
    c = {"server": SERVER, "topic": "lumen-" + secrets.token_urlsafe(18).replace("_", "x").replace("-", "y"),
         "key": b64u(secrets.token_bytes(32)), "created": int(time.time()), "seen": [], "since": "1h"}
    write_private(CONF, c)
    try:
        os.unlink(REMOTE)                    # an old page holds the old key
    except OSError:
        pass
    out(info())


def info():
    c = conf()
    if not c:
        return {"ok": True, "setup": False}
    return {"ok": True, "setup": True, "server": c.get("server", SERVER), "channel": c["topic"][:10] + "…",
            "created": c.get("created", 0), "remote": REMOTE if os.path.exists(REMOTE) else "", "lost": read_json(LOST, {}) or {}}


def remote():
    c = conf()
    if not c:
        return out({"ok": False, "error": "not set up"})
    with open(os.path.join(HERE, "findmy-remote.html")) as f:
        page = f.read()
    page = (page.replace("__SERVER__", json.dumps(c.get("server", SERVER)))
                .replace("__TOPIC__", json.dumps(c["topic"]))
                .replace("__KEY__", json.dumps(c["key"]))
                .replace("__HOST__", json.dumps(socket.gethostname())))
    write_private(REMOTE, page)
    out({"ok": True, "path": REMOTE})


def main(argv):
    if not argv or argv[0] in ("-h", "--help"):
        print(__doc__)
        return 0
    cmd = argv[0]
    if cmd == "setup":
        setup("--rotate" in argv)
    elif cmd == "info":
        out(info())
    elif cmd == "remote":
        remote()
    elif cmd == "lost" and len(argv) >= 2 and argv[1] in ("on", "off"):
        out(dict(set_lost(argv[1] == "on", argv[2] if len(argv) > 2 else "", argv[3] if len(argv) > 3 else ""), ok=True))
    elif cmd == "serve":
        return serve()
    elif cmd == "gather" and len(argv) == 2:
        if argv[1] == "locate":
            out(locate())
        elif argv[1] == "status":
            out(status())
        elif argv[1] in ("photo", "screen"):
            data, err = photo() if argv[1] == "photo" else screen()
            out({"ok": bool(data), "bytes": len(data or b""), "error": err})
    else:
        print(__doc__, file=sys.stderr)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]) or 0)
