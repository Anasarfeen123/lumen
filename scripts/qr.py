#!/usr/bin/env python3
"""qr.py — read QR codes from the screen or an image (OpenCV, on this computer).

  qr.py region            pick a part of the screen (slurp), read what's in it
  qr.py screen            the whole focused screen
  qr.py file <image>
Prints JSON: {"codes": [text, …]} or {"error": …}. A Wi-Fi code
(WIFI:S:<name>;T:WPA;P:<password>;;) comes back as {"wifi": {ssid, password, type}} too.
"""
import json, re, subprocess, sys, tempfile, os


def grab(mode):
    out = tempfile.NamedTemporaryFile(suffix=".png", delete=False).name
    if mode == "region":
        g = subprocess.run(["slurp"], capture_output=True, text=True).stdout.strip()
        if not g:
            return None
        subprocess.run(["grim", "-g", g, out], check=True)
    else:
        mon = json.loads(subprocess.run(["hyprctl", "-j", "monitors"], capture_output=True, text=True).stdout or "[]")
        name = next((m["name"] for m in mon if m.get("focused")), "")
        subprocess.run(["grim"] + (["-o", name] if name else []) + [out], check=True)
    return out


def read(path):
    import cv2
    img = cv2.imread(path)
    if img is None:
        return []
    det = cv2.QRCodeDetector()
    ok, texts, _, _ = det.detectAndDecodeMulti(img)
    codes = [t for t in (texts if ok else []) if t]
    if not codes:                                   # small codes: try it larger
        big = cv2.resize(img, None, fx=2, fy=2, interpolation=cv2.INTER_CUBIC)
        ok, texts, _, _ = det.detectAndDecodeMulti(big)
        codes = [t for t in (texts if ok else []) if t]
    return codes


def wifi(code):
    if not code.startswith("WIFI:"):
        return None
    f = dict(re.findall(r"([STPH]):((?:\\\\.|[^;])*);", code[5:]))
    return {"ssid": f.get("S", ""), "password": f.get("P", ""), "type": f.get("T", "")}


def main():
    a = sys.argv[1:]
    if not a or a[0] not in ("region", "screen", "file"):
        print(__doc__); sys.exit(2)
    path = a[1] if a[0] == "file" else grab(a[0])
    if not path:
        print(json.dumps({"error": "cancelled"})); return
    codes = read(path)
    if a[0] != "file":
        os.unlink(path)
    o = {"codes": codes}
    w = next((wifi(c) for c in codes if wifi(c)), None)
    if w:
        o["wifi"] = w
    print(json.dumps(o if codes else {"error": "No QR code found there."}))


if __name__ == "__main__":
    main()
