#!/usr/bin/env python3
"""notes-sync.py — Lumen Notes ↔ your phone, through Syncthing.

Syncthing does the syncing (both ways, device to device, encrypted, no
account); this only sets it up and reads its state through its local REST API
(127.0.0.1:8384, key from its own config). Standard library only.

  notes-sync.py [--dir D] status        JSON: installed, running, myId, the Notes folder, devices, pending phones
  notes-sync.py [--dir D] setup         start Syncthing for this user (and at login), share the Notes folder
  notes-sync.py qr <out.png>            this computer's ID as a QR code, for the phone to scan
  notes-sync.py accept <deviceId> [name]   trust a phone and share Notes with it
  notes-sync.py forget <deviceId>       stop syncing with a device
  notes-sync.py stop                    stop Syncthing (and don't start it at login)
"""
import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

FOLDER_ID = "lumen-notes"
GUI = "http://127.0.0.1:8384"


def out(obj):
    print(json.dumps(obj, separators=(",", ":")))


def config_xml():
    cands = []
    try:
        r = subprocess.run(["syncthing", "paths"], capture_output=True, text=True, timeout=10)
        for line in r.stdout.splitlines():
            m = re.search(r"(/\S*config\.xml)", line)
            if m:
                cands.append(m.group(1))
    except (OSError, subprocess.TimeoutExpired):
        pass
    state = os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state")
    conf = os.environ.get("XDG_CONFIG_HOME") or os.path.expanduser("~/.config")
    cands += [os.path.join(state, "syncthing", "config.xml"), os.path.join(conf, "syncthing", "config.xml")]
    return next((c for c in cands if os.path.exists(c)), None)


def api_key():
    path = config_xml()
    if not path:
        return None
    try:
        with open(path) as f:
            m = re.search(r"<apikey>([^<]+)</apikey>", f.read())
        return m.group(1) if m else None
    except OSError:
        return None


class Api:
    def __init__(self, key):
        self.key = key

    def call(self, method, path, body=None, raw=False, timeout=10):
        data = json.dumps(body).encode() if body is not None else None
        req = urllib.request.Request(GUI + path, data=data, method=method,
                                     headers={"X-API-Key": self.key, "Content-Type": "application/json"})
        with urllib.request.urlopen(req, timeout=timeout) as r:
            payload = r.read()
        if raw:
            return payload
        return json.loads(payload) if payload.strip() else None


def api(wait=0):
    deadline = time.time() + wait
    while True:
        key = api_key()
        if key:
            a = Api(key)
            try:
                a.call("GET", "/rest/system/ping")
                return a
            except (urllib.error.URLError, OSError, ValueError):
                pass
        if time.time() >= deadline:
            return None
        time.sleep(0.5)


def systemctl(*args):
    return subprocess.run(["systemctl", "--user"] + list(args), capture_output=True, text=True, timeout=30)


def cmd_status(a):
    installed = shutil.which("syncthing") is not None
    res = {"installed": installed, "running": False, "enabled": False, "myId": "", "folder": None,
           "devices": [], "pending": [], "gui": GUI}
    if not installed:
        out(res)
        return
    res["enabled"] = systemctl("is-enabled", "syncthing.service").stdout.strip() == "enabled"
    s = api()
    if not s:
        out(res)
        return
    res["running"] = True
    try:
        status = s.call("GET", "/rest/system/status")
        res["myId"] = status.get("myID", "")
        folders = s.call("GET", "/rest/config/folders") or []
        f = next((x for x in folders if x.get("id") == FOLDER_ID), None)
        shared = {d["deviceID"] for d in (f or {}).get("devices", [])}
        if f:
            try:
                fs = s.call("GET", "/rest/db/status?folder=" + FOLDER_ID)
            except Exception:
                fs = {}
            res["folder"] = {"path": f.get("path"), "paused": f.get("paused", False),
                             "state": fs.get("state", ""), "needFiles": fs.get("needFiles", 0),
                             "errors": fs.get("errors", 0)}
        conns = (s.call("GET", "/rest/system/connections") or {}).get("connections", {})
        try:
            stats = s.call("GET", "/rest/stats/device") or {}
        except Exception:
            stats = {}
        try:
            comp = {}
            for d in s.call("GET", "/rest/config/devices") or []:
                if d["deviceID"] != res["myId"] and d["deviceID"] in shared:
                    c = s.call("GET", "/rest/db/completion?folder=%s&device=%s" % (FOLDER_ID, d["deviceID"]))
                    comp[d["deviceID"]] = round(c.get("completion", 0))
        except Exception:
            comp = {}
        for d in s.call("GET", "/rest/config/devices") or []:
            if d["deviceID"] == res["myId"]:
                continue
            c = conns.get(d["deviceID"], {})
            res["devices"].append({"id": d["deviceID"], "name": d.get("name") or d["deviceID"][:7],
                                   "connected": bool(c.get("connected")), "address": c.get("address", ""),
                                   "shared": d["deviceID"] in shared, "completion": comp.get(d["deviceID"]),
                                   "lastSeen": (stats.get(d["deviceID"]) or {}).get("lastSeen", "")})
        pend = s.call("GET", "/rest/cluster/pending/devices") or {}
        for did, p in pend.items():
            res["pending"].append({"id": did, "name": p.get("name") or did[:7], "address": p.get("address", "")})
    except (urllib.error.URLError, OSError, ValueError) as e:
        res["error"] = str(e)
    out(res)


def cmd_setup(a):
    if not shutil.which("syncthing"):
        out({"ok": False, "error": "Syncthing isn't installed (sudo dnf install syncthing)"})
        return
    os.makedirs(a.dir, exist_ok=True)
    r = systemctl("enable", "--now", "syncthing.service")
    if r.returncode != 0:
        out({"ok": False, "error": (r.stderr or "couldn't start Syncthing").strip()})
        return
    s = api(wait=30)
    if not s:
        out({"ok": False, "error": "Syncthing started but its API didn't answer"})
        return
    folders = s.call("GET", "/rest/config/folders") or []
    if not any(f.get("id") == FOLDER_ID for f in folders):
        s.call("POST", "/rest/config/folders", {
            "id": FOLDER_ID, "label": "Notes", "path": a.dir, "type": "sendreceive",
            "fsWatcherEnabled": True, "fsWatcherDelayS": 2, "rescanIntervalS": 3600,
            # Older copies of changed or deleted notes, kept on this computer
            "versioning": {"type": "simple", "params": {"keep": "10"}},
        })
    # Syncthing's own web UI stays on this computer only
    try:
        gui = s.call("GET", "/rest/config/gui") or {}
        if not str(gui.get("address", "")).startswith("127.0.0.1"):
            s.call("PATCH", "/rest/config/gui", {"address": "127.0.0.1:8384"})
    except (urllib.error.URLError, OSError, ValueError):
        pass
    out({"ok": True, "myId": s.call("GET", "/rest/system/status").get("myID", "")})


def cmd_qr(a):
    s = api(wait=5)
    if not s:
        sys.exit("Syncthing isn't running")
    my = s.call("GET", "/rest/system/status").get("myID", "")
    png = s.call("GET", "/qr/?text=" + urllib.parse.quote(my), raw=True)
    with open(a.out, "wb") as f:
        f.write(png)
    print(a.out)


def valid_id(did):
    return re.fullmatch(r"[A-Z2-7]{7}(-[A-Z2-7]{7}){7}", did or "") is not None


def cmd_accept(a):
    did = a.device.strip().upper()
    if not valid_id(did):
        out({"ok": False, "error": "That isn't a Syncthing device ID"})
        return
    s = api(wait=5)
    if not s:
        out({"ok": False, "error": "Syncthing isn't running"})
        return
    devices = s.call("GET", "/rest/config/devices") or []
    if not any(d["deviceID"] == did for d in devices):
        s.call("POST", "/rest/config/devices", {"deviceID": did, "name": a.name or "Phone",
                                                "addresses": ["dynamic"], "autoAcceptFolders": False})
    folder = s.call("GET", "/rest/config/folders/" + FOLDER_ID)
    if not any(d["deviceID"] == did for d in folder.get("devices", [])):
        s.call("PATCH", "/rest/config/folders/" + FOLDER_ID,
               {"devices": folder.get("devices", []) + [{"deviceID": did}]})
    out({"ok": True})


def cmd_forget(a):
    s = api(wait=5)
    if not s:
        out({"ok": False, "error": "Syncthing isn't running"})
        return
    did = a.device.strip().upper()
    try:
        s.call("DELETE", "/rest/config/devices/" + did)
    except urllib.error.HTTPError:
        pass
    try:
        s.call("DELETE", "/rest/cluster/pending/devices?device=" + did)
    except urllib.error.HTTPError:
        pass
    out({"ok": True})


def cmd_stop(a):
    r = systemctl("disable", "--now", "syncthing.service")
    out({"ok": r.returncode == 0})


def main():
    p = argparse.ArgumentParser(description="Lumen Notes sync (Syncthing)")
    p.add_argument("--dir", default=os.environ.get("LUMEN_NOTES_DIR") or os.path.expanduser("~/Notes"))
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    sub.add_parser("setup")
    q = sub.add_parser("qr"); q.add_argument("out")
    c = sub.add_parser("accept"); c.add_argument("device"); c.add_argument("name", nargs="?", default="")
    f = sub.add_parser("forget"); f.add_argument("device")
    sub.add_parser("stop")
    a = p.parse_args()
    a.dir = os.path.abspath(os.path.expanduser(a.dir))
    globals()["cmd_" + a.cmd](a)


if __name__ == "__main__":
    main()
