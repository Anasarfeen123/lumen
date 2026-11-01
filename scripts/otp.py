#!/usr/bin/env python3
"""otp.py — two-factor codes (TOTP), with the secrets in your keyring.

  otp.py add <name>       read the secret (base32, or an otpauth:// link) from stdin
  otp.py list             JSON: [{"name", "code", "left"}] — codes for now, seconds left
  otp.py code <name>      just the code
  otp.py remove <name>

Secrets live in the desktop keyring (secret-tool, service "lumen-otp"); the
names in ~/.local/state/lumen/otp.json (no secrets in it). Standard TOTP:
SHA-1, 6 digits, 30 seconds, unless an otpauth link says otherwise.
"""
import base64, hashlib, hmac, json, os, struct, subprocess, sys, time, urllib.parse

STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "lumen", "otp.json")


def names():
    try:
        with open(STATE) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save(d):
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    tmp = STATE + ".tmp"
    with open(os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600), "w") as f:
        json.dump(d, f, indent=1)
    os.replace(tmp, STATE)


def secret(name):
    r = subprocess.run(["secret-tool", "lookup", "service", "lumen-otp", "account", name], capture_output=True, text=True)
    return r.stdout.strip()


def totp(sec, digits=6, period=30, algo="sha1", at=None):
    key = base64.b32decode(sec.upper().replace(" ", "") + "=" * (-len(sec.replace(" ", "")) % 8))
    counter = int((at or time.time()) // period)
    h = hmac.new(key, struct.pack(">Q", counter), getattr(hashlib, algo)).digest()
    o = h[-1] & 0x0F
    code = (struct.unpack(">I", h[o:o + 4])[0] & 0x7FFFFFFF) % (10 ** digits)
    return str(code).zfill(digits)


def main():
    a = sys.argv[1:]
    cmd = a[0] if a else ""
    d = names()
    if cmd == "add" and len(a) == 2:
        raw = sys.stdin.read().strip()
        opts = {"digits": 6, "period": 30, "algo": "sha1"}
        if raw.startswith("otpauth://"):
            q = urllib.parse.parse_qs(urllib.parse.urlparse(raw).query)
            raw = q.get("secret", [""])[0]
            opts = {"digits": int(q.get("digits", [6])[0]), "period": int(q.get("period", [30])[0]),
                    "algo": q.get("algorithm", ["SHA1"])[0].lower()}
        totp(raw, **opts)                   # check it's valid before storing
        subprocess.run(["secret-tool", "store", "--label", "Lumen 2FA: " + a[1], "service", "lumen-otp", "account", a[1]],
                       input=raw, text=True, check=True)
        d[a[1]] = opts
        save(d)
        print("saved")
    elif cmd == "list":
        now = time.time()
        out = []
        for n, o in sorted(d.items()):
            s = secret(n)
            if s:
                out.append({"name": n, "code": totp(s, o["digits"], o["period"], o["algo"], now), "left": int(o["period"] - now % o["period"])})
        print(json.dumps(out))
    elif cmd == "code" and len(a) == 2 and a[1] in d:
        o = d[a[1]]
        print(totp(secret(a[1]), o["digits"], o["period"], o["algo"]))
    elif cmd == "remove" and len(a) == 2:
        subprocess.run(["secret-tool", "clear", "service", "lumen-otp", "account", a[1]])
        d.pop(a[1], None)
        save(d)
        print("removed")
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
