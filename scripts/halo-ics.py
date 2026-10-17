#!/usr/bin/env python3
"""halo-ics.py — calendars by iCal link (Google Calendar's "secret address in
iCal format", Outlook, a college calendar…), read-only. Standard library only.

  halo-ics.py list                 JSON: [{name, host}]   (links stay private)
  halo-ics.py add <name> <url>     remember a calendar (the link is kept 600 in
                                   ~/.local/state/lumen/calendars.json)
  halo-ics.py remove <name>
  halo-ics.py events [days]        JSON: [{title, when, end, allDay, location, calendar}]
                                   from now for `days` (30), repeats expanded (daily,
                                   weekly with days, monthly, yearly; COUNT/UNTIL/EXDATE)
Nothing is written to the calendars; links are fetched with one GET each.
"""
import datetime as dt
import json
import os
import re
import sys
import urllib.request

try:
    from zoneinfo import ZoneInfo
except ImportError:                                   # pragma: no cover
    ZoneInfo = None

CONF = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "lumen", "calendars.json")


def load():
    try:
        with open(CONF) as f:
            return json.load(f).get("calendars", [])
    except (OSError, ValueError):
        return []


def save(cals):
    os.makedirs(os.path.dirname(CONF), exist_ok=True)
    old = os.umask(0o077)
    try:
        with open(CONF + ".tmp", "w") as f:
            json.dump({"calendars": cals}, f)
        os.replace(CONF + ".tmp", CONF)
    finally:
        os.umask(old)
    os.chmod(CONF, 0o600)


def unfold(text):
    return re.sub(r"\r?\n[ \t]", "", text).splitlines()


def parse_dt(value, params):
    tz = None
    m = re.search(r"TZID=([^;:]+)", params)
    if m and ZoneInfo:
        try:
            tz = ZoneInfo(m.group(1))
        except Exception:
            tz = None
    if re.fullmatch(r"\d{8}", value):
        d = dt.datetime.strptime(value, "%Y%m%d")
        return d, True
    utc = value.endswith("Z")
    d = dt.datetime.strptime(value.rstrip("Z")[:15], "%Y%m%dT%H%M%S")
    if utc:
        d = d.replace(tzinfo=dt.timezone.utc).astimezone().replace(tzinfo=None)
    elif tz:
        d = d.replace(tzinfo=tz).astimezone().replace(tzinfo=None)
    return d, False


def unescape(s):
    return s.replace("\\n", " ").replace("\\,", ",").replace("\\;", ";").replace("\\\\", "\\").strip()


DAYS = {"MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6}


def expand(start, rule, until_window, exdates):
    """Occurrences of a repeating event up to until_window."""
    r = dict(p.split("=", 1) for p in rule.split(";") if "=" in p)
    freq, interval = r.get("FREQ", ""), int(r.get("INTERVAL", "1") or 1)
    count = int(r["COUNT"]) if "COUNT" in r else None
    until = parse_dt(r["UNTIL"], "")[0] if "UNTIL" in r else None
    bydays = [DAYS[d[-2:]] for d in r.get("BYDAY", "").split(",") if d[-2:] in DAYS]
    out, n, cur = [], 0, start
    limit = min(until_window, until) if until else until_window
    guard = 0
    while cur <= limit and guard < 3000:
        guard += 1
        if freq == "WEEKLY" and bydays:
            week0 = cur - dt.timedelta(days=cur.weekday())
            for wd in sorted(bydays):
                occ = week0 + dt.timedelta(days=wd)
                if occ < start or occ > limit:
                    continue
                n += 1
                if count and n > count:
                    return out
                if occ not in exdates:
                    out.append(occ)
            cur = cur + dt.timedelta(weeks=interval)
            continue
        n += 1
        if count and n > count:
            break
        if cur not in exdates:
            out.append(cur)
        if freq == "DAILY":
            cur += dt.timedelta(days=interval)
        elif freq == "WEEKLY":
            cur += dt.timedelta(weeks=interval)
        elif freq == "MONTHLY":
            m = cur.month - 1 + interval
            try:
                cur = cur.replace(year=cur.year + m // 12, month=m % 12 + 1)
            except ValueError:
                break
        elif freq == "YEARLY":
            try:
                cur = cur.replace(year=cur.year + interval)
            except ValueError:
                break
        else:
            break
    return out


def events(days=30):
    now = dt.datetime.now()
    window = now + dt.timedelta(days=days)
    res = []
    for cal in load():
        try:
            req = urllib.request.Request(cal["url"].replace("webcal://", "https://"), headers={"User-Agent": "Lumen-Halo/1.0"})
            with urllib.request.urlopen(req, timeout=20) as r:
                text = r.read(8_000_000).decode("utf-8", "replace")
        except Exception as e:
            res.append({"error": "%s: %s" % (cal["name"], getattr(e, "reason", e))})
            continue
        ev, inside = {}, False
        for line in unfold(text):
            if line == "BEGIN:VEVENT":
                ev, inside = {"ex": set()}, True
            elif line == "END:VEVENT" and inside:
                inside = False
                if "start" not in ev or ev.get("status") == "CANCELLED":
                    continue
                start, all_day = ev["start"]
                dur = (ev["end"][0] - start) if "end" in ev else (dt.timedelta(days=1) if all_day else dt.timedelta(hours=1))
                occs = expand(start, ev["rrule"], window, ev["ex"]) if "rrule" in ev else [start]
                for o in occs:
                    if o + dur < now or o > window:
                        continue
                    res.append({"title": ev.get("summary", "(no title)"), "when": int(o.timestamp() * 1000),
                                "end": int((o + dur).timestamp() * 1000), "allDay": all_day,
                                "location": ev.get("location", ""), "calendar": cal["name"]})
            elif inside and ":" in line:
                key, value = line.split(":", 1)
                name, _, params = key.partition(";")
                try:
                    if name == "DTSTART":
                        ev["start"] = parse_dt(value, params)
                    elif name == "DTEND":
                        ev["end"] = parse_dt(value, params)
                    elif name == "SUMMARY":
                        ev["summary"] = unescape(value)
                    elif name == "LOCATION":
                        ev["location"] = unescape(value)
                    elif name == "RRULE":
                        ev["rrule"] = value
                    elif name == "STATUS":
                        ev["status"] = value
                    elif name == "EXDATE":
                        for v in value.split(","):
                            ev["ex"].add(parse_dt(v, params)[0])
                except ValueError:
                    pass
    res.sort(key=lambda e: e.get("when", 0))
    return res[:300]


def main():
    a = sys.argv[1:]
    if a and a[0] == "list":
        print(json.dumps([{"name": c["name"], "host": re.sub(r"^\w+://([^/]+).*", r"\1", c["url"])} for c in load()]))
    elif len(a) == 3 and a[0] == "add":
        if not re.match(r"^(https?|webcal)://", a[2]):
            print(json.dumps({"ok": False, "error": "That isn't a calendar link (it should start with https:// or webcal://)."}))
            return
        cals = [c for c in load() if c["name"] != a[1]] + [{"name": a[1], "url": a[2]}]
        save(cals)
        print(json.dumps({"ok": True}))
    elif len(a) == 2 and a[0] == "remove":
        save([c for c in load() if c["name"] != a[1]])
        print(json.dumps({"ok": True}))
    elif a and a[0] == "events":
        print(json.dumps(events(int(a[1]) if len(a) > 1 else 30)))
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
