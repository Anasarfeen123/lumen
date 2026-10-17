#!/usr/bin/env python3
"""amazecc.py — your VIT timetable, attendance, marks and exams for Lumen.

Talks to an AmazeCC API (by default your own, on this computer) which talks to
VTOP. Standard library only.

  amazecc.py status                     JSON: {hasLogin, username, api, apiUp, semester}
  amazecc.py set-login <username>       password on stdin; checks it with VTOP, then keeps it
                                        in the system keyring (Secret Service). Never in a file.
  amazecc.py forget                     removes the login, the session and the synced data
  amazecc.py sync [--threshold 75]      fetch everything, write the snapshot, print what changed:
                                        JSON {ok, error?, updated, changes: [...]}
  amazecc.py extras                     grades/CGPA, circulars, class messages, fees, library dues and
                                        your proctor → amazecc-extra.json (600); JSON {ok, new: {circulars, messages}}
  amazecc.py extra <route> [--body {}]  one read-only VTOP page (grades, class-messages, circulars,
                                        fees-intimation, library-due, proctor, faculty-info…) as JSON

Options (any command): --api URL (default http://127.0.0.1:3000) · --semester ID

Files (all mode 600):
  $XDG_STATE_HOME/lumen/amazecc-data.json      the snapshot the shell reads
  $XDG_STATE_HOME/lumen/amazecc-history.json   marks as they appeared, attendance per day
  $XDG_RUNTIME_DIR/lumen-amazecc-session.json  a VTOP session, reused for 20 minutes (RAM only)
"""
import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.realpath(__file__))
STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "lumen")
DATA = os.path.join(STATE, "amazecc-data.json")
HISTORY = os.path.join(STATE, "amazecc-history.json")
RUNTIME = os.environ.get("XDG_RUNTIME_DIR") or "/tmp"
SESSION = os.path.join(RUNTIME, "lumen-amazecc-session.json")
SECRET_ATTRS = ["service", "lumen-amazecc", "account", "vtop"]
SESSION_TTL = 20 * 60
DAYS = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
MONTHS = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]


def out(obj):
    print(json.dumps(obj, separators=(",", ":")))


def write_private(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    fd = os.open(tmp, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump(obj, f, separators=(",", ":"))
    os.replace(tmp, path)


def read_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


# ── keyring ────────────────────────────────────────────────────────────────

def secret_get():
    try:
        r = subprocess.run(["secret-tool", "lookup"] + SECRET_ATTRS, capture_output=True, text=True, timeout=20)
    except (OSError, subprocess.TimeoutExpired):
        return None
    if r.returncode != 0 or not r.stdout.strip():
        return None
    try:
        d = json.loads(r.stdout)
        return d if d.get("u") and d.get("p") else None
    except ValueError:
        return None


def secret_set(username, password):
    payload = json.dumps({"u": username, "p": password})
    r = subprocess.run(["secret-tool", "store", "--label=AmazeCC (VTOP login for Lumen)"] + SECRET_ATTRS,
                       input=payload, capture_output=True, text=True, timeout=60)
    return r.returncode == 0


def secret_clear():
    subprocess.run(["secret-tool", "clear"] + SECRET_ATTRS, capture_output=True, timeout=20)


# ── API ────────────────────────────────────────────────────────────────────

class ApiError(Exception):
    pass


def post(api, path, body, timeout=120):
    req = urllib.request.Request(api.rstrip("/") + "/api/" + path, data=json.dumps(body).encode(),
                                 headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as r:
            return json.loads(r.read() or b"{}")
    except urllib.error.HTTPError as e:
        try:
            detail = json.loads(e.read() or b"{}")
        except ValueError:
            detail = {}
        msg = detail.get("message") or detail.get("error") or ("HTTP %d" % e.code)
        raise ApiError("%s: %s" % (path, msg)) from None
    except (urllib.error.URLError, TimeoutError, ConnectionError) as e:
        raise ApiError("Can't reach the AmazeCC API at %s (%s)" % (api, getattr(e, "reason", e))) from None
    except ValueError:
        raise ApiError("%s: the API answered with something that isn't JSON" % path) from None


def api_up(api):
    try:
        with urllib.request.urlopen(api.rstrip("/") + "/api/health", timeout=4) as r:
            return r.status == 200
    except Exception:
        return False


def login(api, creds):
    r = post(api, "login", {"username": creds["u"], "password": creds["p"]}, timeout=90)
    if not r.get("success"):
        raise ApiError(r.get("message") or r.get("error") or "VTOP didn't accept the login")
    s = {"cookies": r["cookies"], "csrf": r["csrf"], "authorizedID": r["authorizedID"], "at": time.time()}
    write_private(SESSION, s)
    return s


def session(api, creds, fresh=False):
    s = None if fresh else read_json(SESSION)
    if s and time.time() - s.get("at", 0) < SESSION_TTL:
        return s
    return login(api, creds)


def semesters():
    try:
        with open(os.path.join(HERE, "amazecc-slots.json")) as f:
            return list(json.load(f)["semesters"])
    except (OSError, ValueError, KeyError):
        return []


def default_semester():
    sems = semesters()
    return sems[-2] if len(sems) >= 2 else (sems[0] if sems else "")   # what AmazeCC itself opens by default


# ── parsing ────────────────────────────────────────────────────────────────

def num(s):
    try:
        return float(str(s).strip().rstrip("%"))
    except (TypeError, ValueError):
        return None


def course_kind(code, course_type, slot):
    if code.endswith("(L)") or (slot or "").startswith("L") or "lab" in (course_type or "").lower():
        return "lab"
    return "theory"


def parse_date(s):
    """'12-Oct-2026' · '12/10/2026' · '12-10-2026' → date"""
    parts = re.split(r"[-/ ]+", (s or "").strip())
    if len(parts) != 3:
        return None
    d, m, y = parts
    try:
        mi = int(m) if m.isdigit() else next(i + 1 for i, x in enumerate(MONTHS) if m.lower().startswith(x))
        return dt.date(int(y), mi, int(d))
    except (StopIteration, ValueError):
        return None


def parse_clock(s):
    m = re.search(r"(\d{1,2})[:.](\d{2})\s*([AaPp][Mm])?", s or "")
    if not m:
        return None
    h, mi, ap = int(m.group(1)), int(m.group(2)), (m.group(3) or "").lower()
    if ap == "pm" and h < 12:
        h += 12
    if ap == "am" and h == 12:
        h = 0
    return h * 60 + mi


def ms(day, minutes):
    t = dt.datetime.combine(day, dt.time()) + dt.timedelta(minutes=minutes)
    return int(t.timestamp() * 1000)


def build_week(courses, slots):
    """Per weekday: classes in order, a course's back-to-back slots merged (L1+L2 = one lab)."""
    week = {}
    for day in DAYS:
        items = []
        for c in courses:
            for sid in c["slots"]:
                span = slots.get(day, {}).get(sid)
                if span:
                    items.append({"start": span[0], "end": span[1], "id": c["id"], "code": c["code"],
                                  "title": c["title"], "kind": c["kind"], "venue": c["venue"]})
        items.sort(key=lambda x: (x["start"], x["id"]))
        merged, last = [], {}          # last: course id → its latest merged block
        for it in items:
            prev = last.get(it["id"])
            if prev and 0 <= it["start"] - prev["end"] <= 10:
                prev["end"] = max(prev["end"], it["end"])
            else:
                last[it["id"]] = dict(it)
                merged.append(last[it["id"]])
        week[day] = merged
    return week


def build_courses(attendance, timetable=None):
    # The timetable knows each class's id and room; attendance knows the counts.
    # Both key a course as "BACSE202(T)" / "BACSE202(L)".
    tt = {}
    for t in timetable or []:
        code = re.sub(r"\s+", "", t.get("courseCode") or "")
        if code and t.get("classId"):
            tt[code] = t
    courses = []
    for a in attendance or []:
        code_raw = re.sub(r"\s+", "", a.get("courseCode") or "")
        if not re.sub(r"\((T|L)\)$", "", code_raw) or not (a.get("courseTitle") or "").strip():
            continue                     # VTOP's empty trailing row
        t = tt.get(code_raw, {})
        if not a.get("slotVenue") and t.get("slotVenue"):
            a = dict(a, slotVenue=t["slotVenue"])
        if not a.get("classId") and t.get("classId"):
            a = dict(a, classId=t["classId"])
        # VTOP's "L31+L32 - AB1-607B": the separator is " - " (a bare "-" is inside venues)
        # either "L31+L32 - AB1-607B" (timetable) or just "AB1-607B" (attendance)
        parts = re.split(r"\s+-\s+", (a.get("slotVenue") or "").strip(), maxsplit=1)
        slot_part = parts[0] if len(parts) == 2 else (a.get("slotName") or "")
        venue = parts[1] if len(parts) == 2 else (parts[0] if parts[0] != slot_part else "")
        attended, total = a.get("attendedClasses"), a.get("totalClasses")
        pct = num(a.get("attendancePercentage"))
        if pct is None and total:
            pct = round(100 * attended / total)
        courses.append({
            "id": a.get("classId") or code_raw,
            "code": re.sub(r"\((T|L)\)$", "", code_raw).strip(),
            "title": (a.get("courseTitle") or "").strip(),
            "kind": course_kind(code_raw, a.get("courseType"), a.get("slotName")),
            "type": (a.get("courseType") or "").strip(),
            "slots": [s.strip() for s in slot_part.split("+") if s.strip()],
            "venue": re.sub(r"\s+", " ", venue).strip(),
            "faculty": re.sub(r"\s*-\s*[A-Z]+$", "", (a.get("faculty") or "").strip()),
            "attended": attended if isinstance(attended, int) else None,
            "total": total if isinstance(total, int) else None,
            "pct": pct,
        })
    return courses


def build_marks(marks_res):
    if not isinstance(marks_res, dict):
        return []
    marks = []
    for c in marks_res.get("courses") or []:
        assessments = []
        for a in c.get("assessments") or []:
            assessments.append({
                "title": (a.get("title") or "").strip(),
                "max": num(a.get("maxMark")),
                "scored": num(a.get("scoredMark")),
                "weight": num(a.get("weightagePercent")),
                "weightMark": num(a.get("weightageMark")),
                "status": (a.get("status") or "").strip(),
            })
        marks.append({
            "id": c.get("classNbr") or "",
            "code": (c.get("courseCode") or "").strip(),
            "title": (c.get("courseTitle") or "").strip(),
            "kind": "lab" if "lab" in (c.get("courseType") or "").lower() else "theory",
            "assessments": assessments,
        })
    return marks


def build_exams(schedule_res):
    exams = []
    for kind, items in ((schedule_res or {}).get("Schedule") or {}).items():
        for e in items or []:
            day = parse_date(e.get("examDate"))
            if not day:
                continue
            span = (e.get("examTime") or "").split("-")
            start = parse_clock(span[0]) if span else None
            end = parse_clock(span[1]) if len(span) > 1 else None
            report = parse_clock(e.get("reportingTime"))
            start = start if start is not None else report
            exams.append({
                "kind": kind.strip(),
                "code": (e.get("courseCode") or "").strip(),
                "title": (e.get("courseTitle") or "").strip(),
                "date": day.isoformat(),
                "when": ms(day, start) if start is not None else ms(day, 0),
                "end": ms(day, end) if end is not None else None,
                "timed": start is not None,
                "reporting": (e.get("reportingTime") or "").strip(),
                "time": (e.get("examTime") or "").strip(),
                "venue": (e.get("venue") or "").strip(),
                "seat": " · ".join(x for x in [(e.get("seatLocation") or "").strip(), (e.get("seatNo") or "").strip()] if x and x != "-"),
            })
    exams.sort(key=lambda x: x["when"])
    return exams


def build_days(calendar_res):
    """Holidays, and Saturdays that follow another day's timetable ('Monday Day Order')."""
    days = []
    for cal in (calendar_res or {}).get("calendars") or []:
        if not isinstance(cal, dict):
            continue
        label = str(cal.get("month") or "")
        mm = next((i + 1 for i, x in enumerate(MONTHS) if x in label.lower()), None)
        ym = re.search(r"(20\d\d)", label)
        if not mm or not ym:
            continue
        for d in cal.get("days") or []:
            try:
                day = dt.date(int(ym.group(1)), mm, int(d.get("date")))
            except (TypeError, ValueError):
                continue
            events = d.get("events") or []
            text = " · ".join(e.get("text", "").strip() for e in events if e.get("text"))
            holiday = any(e.get("type") == "Holiday" for e in events) or bool(re.search(r"holiday|no instructional", text, re.I))
            order = re.search(r"(mon|tues|wednes|thurs|fri|satur|sun)day\s+day\s*order", text, re.I)
            days.append({
                "date": day.isoformat(),
                "kind": "holiday" if holiday else "instructional" if re.search(r"instructional", text, re.I) else "other",
                "text": text,
                "order": order.group(1)[:3].upper() if order else None,
            })
    days.sort(key=lambda x: x["date"])
    return days


# ── calendar file (.ics) for the phone ──────────────────────────────────────

def ics_escape(t):
    return (t or "").replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace("\n", "\\n")


def ics_utc(day, minutes):
    local = dt.datetime.combine(day, dt.time()) + dt.timedelta(minutes=minutes)
    return local.astimezone(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")


def write_ics(path, snap):
    """Every class as its own dated event (holidays skipped, day-order Saturdays
    followed), exams, and holidays — from a week ago to the last instructional day."""
    days = {d["date"]: d for d in snap["days"]}
    instructional = [d["date"] for d in snap["days"] if d["kind"] == "instructional" or d["order"]]
    exam_dates = [e["date"] for e in snap["exams"]]
    today = dt.date.today()
    start = today - dt.timedelta(days=7)
    last = max(instructional + exam_dates + [today.isoformat()])
    end = dt.date.fromisoformat(last)
    stamp = dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ")
    out = ["BEGIN:VCALENDAR", "VERSION:2.0", "PRODID:-//Lumen//AmazeCC//EN", "CALSCALE:GREGORIAN",
           "X-WR-CALNAME:VIT — " + snap.get("semester", ""), "X-PUBLISHED-TTL:PT1H"]
    def event(uid, summary, location, dtstart, dtend, desc="", allday=False):
        out.extend(["BEGIN:VEVENT", "UID:" + uid, "DTSTAMP:" + stamp,
                    ("DTSTART;VALUE=DATE:" if allday else "DTSTART:") + dtstart,
                    ("DTEND;VALUE=DATE:" if allday else "DTEND:") + dtend,
                    "SUMMARY:" + ics_escape(summary)]
                   + (["LOCATION:" + ics_escape(location)] if location else [])
                   + (["DESCRIPTION:" + ics_escape(desc)] if desc else []) + ["END:VEVENT"])
    d = start
    while d <= end:
        info = days.get(d.isoformat())
        if info and info["kind"] == "holiday" and not info["order"]:
            if re.search(r"\(([^)]+)\)", info["text"]) or d.weekday() < 5:
                name = (re.search(r"\(([^)]+)\)", info["text"]) or [None, "Holiday"])[1]
                event("hol-%s@lumen-amazecc" % d.isoformat(), name + " — no classes", "", d.strftime("%Y%m%d"),
                      (d + dt.timedelta(days=1)).strftime("%Y%m%d"), allday=True)
        else:
            order = (info or {}).get("order") or DAYS[d.weekday()]
            if d.weekday() < 5 or (info and info.get("order")):
                for c in snap["week"].get(order, []):
                    event("cls-%s-%s-%d@lumen-amazecc" % (d.isoformat(), c["id"], c["start"]),
                          c["title"] + (" (lab)" if c["kind"] == "lab" else ""), c["venue"],
                          ics_utc(d, c["start"]), ics_utc(d, c["end"]), c["code"])
        d += dt.timedelta(days=1)
    for e in snap["exams"]:
        day = dt.date.fromisoformat(e["date"])
        start_min = (dt.datetime.fromtimestamp(e["when"] / 1000) - dt.datetime.combine(day, dt.time())).seconds // 60
        end_min = (dt.datetime.fromtimestamp(e["end"] / 1000) - dt.datetime.combine(day, dt.time())).seconds // 60 if e.get("end") else start_min + 180
        event("exam-%s-%s@lumen-amazecc" % (e["kind"], e["code"]), e["kind"] + " · " + e["title"], e["venue"],
              ics_utc(day, start_min), ics_utc(day, end_min),
              " · ".join(x for x in ["Report " + e["reporting"] if e.get("reporting") else "", "Seat " + e["seat"] if e.get("seat") else ""] if x))
    out.append("END:VCALENDAR")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        f.write("\r\n".join(out) + "\r\n")
    os.replace(tmp, path)
    return sum(1 for l in out if l == "BEGIN:VEVENT")


# ── what changed since last time ───────────────────────────────────────────

def diff(prev, new, threshold):
    if not prev:
        return []          # first sync: nothing is "new"
    changes = []

    old_marks = {}
    for c in prev.get("marks") or []:
        for a in c.get("assessments") or []:
            old_marks[(c["id"], a["title"])] = a.get("scored")
    for c in new["marks"]:
        for a in c["assessments"]:
            if a["scored"] is None:
                continue
            before = old_marks.get((c["id"], a["title"]), "missing")
            if before == a["scored"]:
                continue
            changes.append({"kind": "mark", "id": c["id"], "code": c["code"], "title": c["title"],
                            "assessment": a["title"], "scored": a["scored"], "max": a["max"],
                            "weightMark": a["weightMark"], "weight": a["weight"],
                            "updated": before not in ("missing", None)})

    old_att = {c["id"]: c for c in prev.get("courses") or []}
    for c in new["courses"]:
        o = old_att.get(c["id"])
        if not o or c["pct"] is None or o.get("total") == c["total"]:
            continue
        crossed_below = (o.get("pct") or 100) >= threshold > c["pct"]
        near = threshold <= c["pct"] < threshold + 5 and (c["pct"] < (o.get("pct") or 100))
        if crossed_below or near or (c["pct"] < threshold and c["pct"] < (o.get("pct") or 100)):
            changes.append({"kind": "attendance", "id": c["id"], "code": c["code"], "title": c["title"],
                            "kindOf": c["kind"], "pct": c["pct"], "prevPct": o.get("pct"),
                            "attended": c["attended"], "total": c["total"],
                            "state": "below" if c["pct"] < threshold else "near"})

    old_exams = {(e["kind"], e["code"]): e for e in prev.get("exams") or []}
    for e in new["exams"]:
        o = old_exams.get((e["kind"], e["code"]))
        if not o:
            changes.append(dict(e, kind="exam", examKind=e["kind"], what="scheduled"))
        elif e["seat"] and e["seat"] != o.get("seat"):
            changes.append(dict(e, kind="exam", examKind=e["kind"], what="seat"))
        elif e["when"] != o.get("when"):
            changes.append(dict(e, kind="exam", examKind=e["kind"], what="moved"))
    return changes


# ── history: when marks appeared, attendance day by day (kept 400 days) ─────

def record_history(snap, changes):
    h = read_json(HISTORY) or {"marks": [], "attendance": {}}
    now = int(time.time() * 1000)
    for c in changes:
        if c["kind"] == "mark":
            h["marks"].append({"t": now, "id": c["id"], "title": c["title"], "assessment": c["assessment"],
                               "scored": c["scored"], "max": c["max"]})
    today = dt.date.today().isoformat()
    h["attendance"][today] = {c["id"]: [c["attended"], c["total"], c["pct"]] for c in snap["courses"] if c["total"]}
    cutoff = (dt.date.today() - dt.timedelta(days=400)).isoformat()
    h["attendance"] = {d: v for d, v in h["attendance"].items() if d >= cutoff}
    h["marks"] = h["marks"][-2000:]
    write_private(HISTORY, h)
    # A week ago (the closest day on or before), for trends
    week = (dt.date.today() - dt.timedelta(days=7)).isoformat()
    past = [d for d in h["attendance"] if d <= week]
    return h["attendance"][max(past)] if past else None


# ── commands ───────────────────────────────────────────────────────────────

def cmd_status(a):
    creds = secret_get()
    snap = read_json(DATA) or {}
    out({"hasLogin": bool(creds), "username": creds["u"] if creds else "", "api": a.api,
         "apiUp": api_up(a.api), "semester": a.semester or default_semester(),
         "defaultSemester": default_semester(), "semesters": semesters(),
         "updated": snap.get("updated", 0)})


def cmd_set_login(a):
    password = sys.stdin.readline().rstrip("\n")
    username = (a.username or "").strip().upper()
    if not username or not password:
        out({"ok": False, "error": "Enter your VTOP username and password"})
        return
    try:
        login(a.api, {"u": username, "p": password})
    except ApiError as e:
        out({"ok": False, "error": str(e)})
        return
    if not secret_set(username, password):
        out({"ok": False, "error": "Couldn't save to the keyring (is a Secret Service like gnome-keyring or KWallet running?)"})
        return
    out({"ok": True, "username": username})


def cmd_forget(a):
    secret_clear()
    for p in (SESSION, DATA):
        try:
            os.remove(p)
        except OSError:
            pass
    out({"ok": True})


def fetch_all(api, s, semester):
    base = {"cookies": s["cookies"], "csrf": s["csrf"], "authorizedID": s["authorizedID"], "semesterId": semester}
    att = post(api, "attendance", base, timeout=180)
    attendance = ((att or {}).get("attRes") or {}).get("attendance")
    if not attendance:
        raise ApiError("session")             # an expired VTOP session reads as an empty list
    try:
        tt = (post(api, "timetable", base) or {}).get("courseInfo") or []
    except ApiError:
        tt = []
    try:
        sched = post(api, "schedule", base)
    except ApiError:
        sched = None
    try:
        cal = post(api, "calendar", dict(base, type="ALL"), timeout=180)
    except ApiError:
        cal = None
    return att, tt, sched, cal


def cmd_sync(a):
    creds = secret_get()
    if not creds:
        out({"ok": False, "error": "nologin"})
        return
    semester = a.semester or default_semester()
    prev = read_json(DATA)
    try:
        s = session(a.api, creds)
        try:
            att, tt, sched, cal = fetch_all(a.api, s, semester)
        except ApiError as e:
            if str(e) != "session" and "session" not in str(e).lower():
                raise
            s = session(a.api, creds, fresh=True)
            att, tt, sched, cal = fetch_all(a.api, s, semester)
    except ApiError as e:
        out({"ok": False, "error": "VTOP returned no courses for this semester" if str(e) == "session" else str(e)})
        return

    with open(os.path.join(HERE, "amazecc-slots.json")) as f:
        slots = json.load(f)["slots"]
    courses = build_courses(att["attRes"]["attendance"], tt)
    snap = {
        "version": 1,
        "updated": int(time.time() * 1000),
        "semester": semester,
        "courses": courses,
        "week": build_week(courses, slots),
        "marks": build_marks(att.get("marksRes")),
        # Keep what we knew if a part failed this time
        "exams": build_exams(sched) if sched is not None else (prev or {}).get("exams", []),
        "days": build_days(cal) if cal is not None else (prev or {}).get("days", []),
    }
    changes = diff(prev, snap, a.threshold)
    try:
        snap["weekAgo"] = record_history(snap, changes)
    except (OSError, ValueError, KeyError):
        snap["weekAgo"] = (prev or {}).get("weekAgo")
    write_private(DATA, snap)
    events = 0
    if a.ics:
        try:
            events = write_ics(os.path.expanduser(a.ics), snap)
        except (OSError, ValueError, KeyError):
            events = -1
    out({"ok": True, "updated": snap["updated"], "changes": changes, "calendarEvents": events,
         "partial": [n for n, v in (("exams", sched), ("calendar", cal)) if v is None]})


# Read-only extras (grades, class messages, circulars, dues…): one VTOP page each,
# through the same session. Only routes that read are allowed here.
EXTRA_ROUTES = {"grades", "all-grades", "class-messages", "circulars", "fees-intimation", "library-due", "proctor",
                "proctor-messages", "faculty-info", "marks/stats", "course-page", "curriculum", "biometric", "hostel-leave",
                "od", "transcript", "profile-images", "student", "me", "registration-status", "wallet", "capstone",
                "mess-selection", "credentials", "outcome-set", "late-hour", "university-day"}


def cmd_extra(a):
    if a.route not in EXTRA_ROUTES:
        out({"ok": False, "error": "not a read-only route Lumen uses"})
        return
    creds = secret_get()
    if not creds:
        out({"ok": False, "error": "nologin"})
        return
    body = json.loads(a.body or "{}")
    try:
        s = session(a.api, creds)
        base = {"cookies": s["cookies"], "csrf": s["csrf"], "authorizedID": s["authorizedID"], "semesterId": a.semester or default_semester()}
        try:
            r = post(a.api, a.route, dict(base, **body), timeout=180)
        except ApiError:
            s = session(a.api, creds, fresh=True)
            base.update({"cookies": s["cookies"], "csrf": s["csrf"], "authorizedID": s["authorizedID"]})
            r = post(a.api, a.route, dict(base, **body), timeout=180)
    except ApiError as e:
        out({"ok": False, "error": str(e)})
        return
    out({"ok": True, "data": r})


EXTRA = os.path.join(STATE, "amazecc-extra.json")


def flatten_circulars(nodes, path=()):
    out = []
    for n in nodes or []:
        if n.get("id"):
            t = n.get("title", "")
            m = re.search(r"\[\s*(\d{1,2}-[A-Z]{3}-\d{4})\s*\]", t)
            when = 0
            if m:
                try:
                    when = int(dt.datetime.strptime(m.group(1), "%d-%b-%Y").timestamp() * 1000)
                except ValueError:
                    pass
            title = re.sub(r"\.pdf\s*\[.*?\]\s*$", "", t, flags=re.I).strip()
            out.append({"id": n["id"], "title": title, "office": path[0] if path else "", "date": when})
        out += flatten_circulars(n.get("children"), path + ((n.get("name") or ""),))
    return out


def cmd_extras(a):
    """Grades/CGPA, circulars, class messages, fees, library dues and your proctor —
    one snapshot (600) the shell reads; prints what's new since the last one."""
    creds = secret_get()
    if not creds:
        out({"ok": False, "error": "nologin"})
        return
    prev = read_json(EXTRA) or {}
    snap = {"updated": int(time.time() * 1000)}
    try:
        s = session(a.api, creds)
    except ApiError as e:
        out({"ok": False, "error": str(e)})
        return
    base = {"cookies": s["cookies"], "csrf": s["csrf"], "authorizedID": s["authorizedID"], "semesterId": a.semester or default_semester()}

    def get(route, keep=None):
        try:
            return post(a.api, route, base, timeout=180) or {}
        except ApiError:
            return keep if keep is not None else {}
    g = get("grades")
    if g.get("cgpa"):
        snap["cgpa"] = g["cgpa"]
        snap["grades"] = [{"title": x.get("basketTitle", ""), "grade": x.get("grade", ""), "credits": num(x.get("creditsEarned")), "type": x.get("courseType", "")}
                          for x in g.get("effectiveGrades") or []]
    else:
        for k in ("cgpa", "grades"):
            if k in prev:
                snap[k] = prev[k]
    c = get("circulars")
    snap["circulars"] = sorted(flatten_circulars(c.get("circulars")), key=lambda x: -x["date"])[:40] if c.get("circulars") is not None else prev.get("circulars", [])
    m = get("class-messages")
    snap["messages"] = m.get("messages") if isinstance(m.get("messages"), list) else prev.get("messages", [])
    f = get("fees-intimation")
    snap["fees"] = {k: f.get(k) for k in ("tuitionFee", "dueDateWithoutLateFee", "dueDateWithLateFee", "lateFeePerDay")} if f.get("success") else prev.get("fees")
    lib = get("library-due")
    due = ((lib.get("keyValuePairs") or {}).get("kohaDueAmount") or "")
    snap["library"] = {"due": num(re.sub(r"[^0-9.]", "", due)) or 0} if lib.get("success") else prev.get("library")
    pr = get("proctor")
    snap["proctor"] = pr.get("details") if pr.get("details") else prev.get("proctor")
    write_private(EXTRA, snap)
    old_c = {x["id"] for x in prev.get("circulars", [])}
    old_m = {json.dumps(x, sort_keys=True) for x in prev.get("messages", [])}
    out({"ok": True, "updated": snap["updated"],
         "new": {"circulars": [x for x in snap["circulars"] if prev and x["id"] not in old_c][:5],
                 "messages": [x for x in snap["messages"] if prev and json.dumps(x, sort_keys=True) not in old_m][:5]}})


def main():
    p = argparse.ArgumentParser(description="AmazeCC for Lumen")
    p.add_argument("--api", default=os.environ.get("LUMEN_AMAZECC_API") or "http://127.0.0.1:3000")
    p.add_argument("--semester", default="")
    p.add_argument("--threshold", type=float, default=75)
    p.add_argument("--ics", default="", help="also write the timetable, exams and holidays as an .ics file here")
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    sl = sub.add_parser("set-login")
    sl.add_argument("username")
    sub.add_parser("forget")
    sub.add_parser("sync")
    sub.add_parser("extras", help="grades/CGPA, circulars, class messages, fees, library, proctor → amazecc-extra.json")
    ex = sub.add_parser("extra", help="one read-only VTOP page (grades, class-messages, circulars…) as JSON")
    ex.add_argument("route")
    ex.add_argument("--body", default="", help="extra JSON fields for the route")
    a = p.parse_args()
    {"status": cmd_status, "set-login": cmd_set_login, "forget": cmd_forget, "sync": cmd_sync, "extra": cmd_extra, "extras": cmd_extras}[a.cmd](a)


if __name__ == "__main__":
    main()
