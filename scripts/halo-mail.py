#!/usr/bin/env python3
"""halo-mail.py — your inbox for Halo, read-only (IMAP). Standard library only.

  halo-mail.py status            JSON: {configured, user, host}
  halo-mail.py set <host> <user> the password (an app password) is read from stdin,
                                 never the command line; kept 600 in
                                 ~/.local/state/lumen/mail.json
  halo-mail.py remove            forget it
  halo-mail.py test              JSON: {ok, unread} or {ok: false, error}
  halo-mail.py unread [n]        JSON: [{uid, from, email, subject, date}] — the newest n (20)
                                 unread in the inbox. Only headers; the inbox is opened
                                 read-only and nothing is marked read.
Halo never sends mail itself: drafts open in your mail (Gmail's compose page).
For Gmail: turn on 2-Step Verification, then make an app password at
https://myaccount.google.com/apppasswords and paste it in Settings → Halo.
"""
import email.header
import email.utils
import imaplib
import json
import os
import sys

CONF = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "lumen", "mail.json")


def out(o):
    print(json.dumps(o))


def load():
    try:
        with open(CONF) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def save(c):
    os.makedirs(os.path.dirname(CONF), exist_ok=True)
    old = os.umask(0o077)
    try:
        with open(CONF + ".tmp", "w") as f:
            json.dump(c, f)
        os.replace(CONF + ".tmp", CONF)
    finally:
        os.umask(old)
    os.chmod(CONF, 0o600)


def dec(v):
    try:
        return str(email.header.make_header(email.header.decode_header(v or ""))).strip()
    except Exception:
        return (v or "").strip()


def connect(c):
    m = imaplib.IMAP4_SSL(c["host"], int(c.get("port", 993)), timeout=20)
    m.login(c["user"], c["password"])
    m.select("INBOX", readonly=True)
    return m


def unread(n=20):
    c = load()
    if not c.get("password"):
        return {"error": "not set up"}
    try:
        m = connect(c)
        typ, data = m.uid("search", None, "UNSEEN")
        uids = (data[0] or b"").split()[-n:]
        res = []
        for uid in reversed(uids):
            typ, msg = m.uid("fetch", uid, "(BODY.PEEK[HEADER.FIELDS (FROM SUBJECT DATE)])")
            raw = next((part[1] for part in msg if isinstance(part, tuple)), b"")
            h = email.message_from_bytes(raw)
            name, addr = email.utils.parseaddr(dec(h.get("From")))
            when = email.utils.parsedate_to_datetime(h["Date"]).timestamp() * 1000 if h.get("Date") else 0
            res.append({"uid": uid.decode(), "from": name or addr, "email": addr, "subject": dec(h.get("Subject")) or "(no subject)", "date": int(when)})
        m.logout()
        return res
    except (imaplib.IMAP4.error, OSError) as e:
        return {"error": str(e)}


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        sys.exit(2)
    if a[0] == "status":
        c = load()
        out({"configured": bool(c.get("password")), "user": c.get("user", ""), "host": c.get("host", "")})
    elif a[0] == "set" and len(a) == 3:
        pw = sys.stdin.readline().strip().replace(" ", "")
        if not pw:
            out({"ok": False, "error": "No password given."})
            return
        save({"host": a[1], "user": a[2], "password": pw, "port": 993})
        r = unread(1)
        out({"ok": not (isinstance(r, dict) and r.get("error")), "error": r.get("error", "") if isinstance(r, dict) else ""})
    elif a[0] == "remove":
        try:
            os.remove(CONF)
        except OSError:
            pass
        out({"ok": True})
    elif a[0] == "test":
        r = unread(50)
        out({"ok": False, "error": r["error"]} if isinstance(r, dict) else {"ok": True, "unread": len(r)})
    elif a[0] == "unread":
        out(unread(int(a[1]) if len(a) > 1 else 20))
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
