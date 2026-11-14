#!/usr/bin/env python3
"""study.py — Lumen's study companion: your Academics folder, past papers (PYQs),
VTOP's lecture plans and syllabi, and your progress. Standard library only.

  study.py courses                 your current courses, each with its Academics folder
  study.py pyq sync [--force]      fetch the MIC PYQ list (at most once every 20 h unless
                                   --force) and download new papers for your courses into
                                   <course>/Exams & Question Papers/PYQs/  → {new: [...]}
  study.py pyq list                every paper Lumen knows for your courses, with "done"
  study.py done <paper-id> [--undo]          mark a paper practised
  study.py lectures sync           VTOP's lecture plan for each course (date, slot, topic)
                                   and its syllabus PDF (into <course>/Syllabus/) → lectures.json
  study.py missed                  classes you were marked absent for (from the attendance
                                   history), with that day's topic from the lecture plan
  study.py attendance              classes left this semester per course, and how many you
                                   can still miss and stay at or above 75 %
  study.py topics <code>           how often each lecture-plan topic shows up in the course's PYQs
  study.py index                   (re)build the text index of your notes and PDFs (incremental)
  study.py search <words…>         files by name and by what's inside them
  study.py classify <file>         which course and subfolder a file probably belongs in
  study.py file <file> <code> <subfolder>    move it there (never overwrites: adds " (2)")
  study.py recent [n]              files in Academics you opened or changed lately
  study.py newsem <semester name> [--apply]  the folder tree for a new semester (preview by default)
  study.py backup                  the nightly vault backup: last run, last commit, repo size
  study.py ocr <folder>            text from photos of papers (tesseract), kept next to them as .txt
  study.py cards <code>            flashcards from the course's cheat sheets (and flashcards.json)
  study.py review <code> <card-id> <0-3>     spaced repetition: again / hard / good / easy
  study.py log <code> <minutes>    a study session; study.py stats → minutes per course per week
  study.py module <code> <n> [--undo]        a syllabus module revised
  study.py events                  upcoming campus events (VTOP, public)
  study.py buses [stop]            bus routes and their stops
  study.py overview                everything the Study app shows, in one JSON

State: ~/.local/state/lumen/study/ (700). Downloads only from the MIC PYQ site
and Google Drive links it lists, and from your own AmazeCC API.
"""
import datetime as dt
import glob
import html
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

HOME = os.path.expanduser("~")
ACAD = os.environ.get("LUMEN_ACADEMICS") or os.path.join(HOME, "Academics")
LSTATE = os.path.join(os.environ.get("XDG_STATE_HOME") or HOME + "/.local/state", "lumen")
STATE = os.path.join(LSTATE, "study")
CACHE = os.path.join(os.environ.get("XDG_CACHE_HOME") or HOME + "/.cache", "lumen", "study")
API = os.environ.get("LUMEN_AMAZECC_API") or "http://127.0.0.1:3000"
PYQ_SITE = "https://pyq.microsoftinnovationsclub.in"
UA = "Lumen-study/1.0 (personal study helper; one fetch a day)"

SUBS = ["Lecture Slides & Notes", "Exams & Question Papers", "Assignments & Labs",
        "Revision & Cheat Sheets", "Syllabus", "Practice Problems"]
PYQ_DIR = os.path.join("Exams & Question Papers", "PYQs")
# folders never indexed or searched: Unity/IDE build output, VCS, caches
SKIP_DIRS = {".git", "Library", "Temp", "Logs", "obj", "Build", "Builds", "node_modules", "__pycache__",
             ".gradle", ".idea", ".vs", ".vscode", "UserSettings", "MemoryCaptures", "Packages", ".cache"}
SKIP_EXT = {".meta", ".cs", ".pyc", ".dll", ".bin", ".hlsl", ".shadergraph", ".shadersubgraph",
            ".mvfrm", ".asset", ".prefab", ".unity", ".mat", ".anim", ".controller"}
TEXT_EXT = {".md", ".txt", ".tex", ".java", ".c", ".py", ".sql"}
# the same course under another name on the PYQ site
ALIASES = {
    "modelsofcomputation": ["theoryofcomputation", "automatatheory", "formallanguagesandautomata"],
    "databasesystems": ["databasemanagementsystems", "databasemanagementsystem"],
    "operatingsystems": ["operatingsystem"],
    "problemsolvingusingjava": ["javaprogramming", "programminginjava"],
}
# short names the paper collections file courses under (whole words only)
NICKNAMES = {
    "modelsofcomputation": ["toc", "moc", "automata", "theory of computation"],
    "databasesystems": ["dbms", "database systems", "database management"],
    "operatingsystems": ["os", "operating systems", "operating system"],
    "problemsolvingusingjava": ["java"],
    "fundamentalsofaugmentedandvirtualreality": ["ar vr", "arvr", "augmented reality", "virtual reality"],
}
# the paper collections (docs/STUDY.md): name → what Lumen calls it
GITHUB = [("Nirant07/VIT-Papers", "main", "VIT-Papers"), ("puneet-chandna/VIT-PYQPs-Paaji", "main", "VIT-PYQPs-Paaji")]
EXAMCOOKER = "https://examcooker.acmvit.in"


# ── basics ──────────────────────────────────────────────────────────────────

def out(o):
    print(json.dumps(o, ensure_ascii=False))


def read_json(p, default=None):
    try:
        with open(p) as f:
            return json.load(f)
    except (OSError, ValueError):
        return default


def write_json(p, o):
    os.makedirs(os.path.dirname(p), mode=0o700, exist_ok=True)
    tmp = p + ".tmp"
    with open(tmp, "w") as f:
        json.dump(o, f, ensure_ascii=False)
    os.chmod(tmp, 0o600)
    os.replace(tmp, p)


def norm(s):
    return re.sub(r"[^a-z0-9]", "", (s or "").lower().replace("&", "and"))


def safe_name(s):
    return re.sub(r"[^A-Za-z0-9._ ()&,+-]+", "_", s).strip(" .") or "file"


def unique_path(p):
    if not os.path.exists(p):
        return p
    root, ext = os.path.splitext(p)
    n = 2
    while os.path.exists("%s (%d)%s" % (root, n, ext)):
        n += 1
    return "%s (%d)%s" % (root, n, ext)


def now_ms():
    return int(time.time() * 1000)


def fetch(url, timeout=40, data=None, headers=None):
    req = urllib.request.Request(url, data=data, headers=dict({"User-Agent": UA}, **(headers or {})))
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read(), r.headers.get_content_type()


# ── courses ↔ folders ──────────────────────────────────────────────────────

def snapshot():
    return read_json(os.path.join(LSTATE, "amazecc-data.json"), {}) or {}


def current_semester_dir():
    if not os.path.isdir(ACAD):
        return None
    dirs = [d for d in os.listdir(ACAD) if d.startswith("Semester") and os.path.isdir(os.path.join(ACAD, d))]
    cur = [d for d in dirs if "(Current)" in d]
    if cur:
        return os.path.join(ACAD, cur[0])
    nums = sorted(dirs, key=lambda d: int((re.findall(r"\d+", d) or ["0"])[0]))
    return os.path.join(ACAD, nums[-1]) if nums else None


def courses():
    snap, sem = snapshot(), current_semester_dir()
    folders = sorted(os.listdir(sem)) if sem else []
    seen, out_ = {}, []
    for c in snap.get("courses", []):
        code = c.get("code") or ""
        if not code or code in seen:
            if code in seen:
                seen[code]["ids"].append(c["id"])
                seen[code]["kinds"].append(c.get("kind"))
            continue
        folder = next((f for f in folders if f.upper().startswith(code.upper())), None) \
            or next((f for f in folders if norm(c.get("title")) and norm(c.get("title")) in norm(f)), None)
        e = {"code": code, "title": re.sub(r"\s+", " ", c.get("title") or "").strip(), "ids": [c["id"]],
             "kinds": [c.get("kind")], "faculty": c.get("faculty") or "", "slots": c.get("slots") or [],
             "folder": os.path.join(sem, folder) if folder else None}
        seen[code] = e
        out_.append(e)
    return out_


def course_of(code):
    return next((c for c in courses() if c["code"].upper() == code.upper()), None)


# ── PYQs ────────────────────────────────────────────────────────────────────

def exam_type(s):
    s = (s or "").upper()
    if "FAT" in s:
        return "FAT"
    m = re.search(r"CAT\s*-?\s*(I{1,2}|[12])\b", s)
    if m:
        return "CAT " + ("1" if m.group(1) in ("1", "I") else "2")
    return s.strip() or "Paper"


def paper_matches(course, p):
    pc = re.sub(r"[A-Z]$", "", (p.get("courseCode") or "").upper())
    if pc and pc == re.sub(r"[A-Z]$", "", course["code"].upper()):
        return True
    t, pt = norm(course["title"]), norm(p.get("courseTitle"))
    return bool(pt) and (pt == t or pt in ALIASES.get(t, []))


def drive_id(url):
    m = re.search(r"/d/([A-Za-z0-9_-]{10,})", url or "") or re.search(r"[?&]id=([A-Za-z0-9_-]{10,})", url or "")
    return m.group(1) if m else None


def download_drive(fid, dest):
    for url in ("https://drive.google.com/uc?export=download&id=" + fid,
                "https://drive.usercontent.google.com/download?export=download&confirm=t&id=" + fid):
        try:
            body, _ = fetch(url, timeout=90)
        except (urllib.error.URLError, TimeoutError, OSError):
            continue
        if body[:5] == b"%PDF-" or body[:4] in (b"\x89PNG", b"\xff\xd8\xff\xe0", b"\xff\xd8\xff\xe1"):
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with open(dest + ".part", "wb") as f:
                f.write(body)
            os.replace(dest + ".part", dest)
            return True
    return False


def pyq_state():
    return read_json(os.path.join(STATE, "pyq.json"), {"fetchedAt": 0, "papers": []})


def progress():
    return read_json(os.path.join(STATE, "progress.json"), {}) or {}


def save_progress(p):
    write_json(os.path.join(STATE, "progress.json"), p)


def sha1_file(path):
    import hashlib
    h = hashlib.sha1()
    try:
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
    except OSError:
        return ""
    return h.hexdigest()


def course_words(c):
    """lowercase phrases a collection might file this course under."""
    key = norm(c["title"])
    out = {c["title"].lower(), c["code"].lower()} | set(NICKNAMES.get(key, []))
    abbr = re.findall(r"\(([A-Za-z-]{2,8})\)", os.path.basename(c["folder"] or ""))
    out |= {a.lower().replace("-", " ") for a in abbr}
    return out


def folder_matches(c, path):
    """a GitHub collection's folder ("all papers/DBMS ( Database management systems)/CAT1") for this course?"""
    folder = os.path.dirname(path)
    if re.search(r"(?i)\bPM[A-Z]{2,3}\d{3}", folder):          # postgraduate (MCA…) versions: a different syllabus
        return False
    text = " " + re.sub(r"[^a-z0-9]+", " ", folder.lower()) + " "
    return any(" %s " % re.sub(r"[^a-z0-9]+", " ", w).strip() in text for w in course_words(c) if w.strip())


def add_paper(st, known, hashes, c, pid, ex, yr, slot, source, view, fetcher, extra=None):
    """download one paper (fetcher(dest) → bool), unless an identical file is already there."""
    name = safe_name("%s %s%s" % (ex, yr or "year unknown", (" Slot " + slot) if slot else "")) + ".pdf"
    dest = unique_path(os.path.join(c["folder"], PYQ_DIR, name))
    if not fetcher(dest):
        return None
    h = sha1_file(dest)
    if h in hashes:                                       # the same paper from another collection
        os.remove(dest)
        known[pid] = {"id": pid, "code": c["code"], "duplicateOf": hashes[h], "path": "", "exam": ex, "year": yr, "slot": slot}
        return None
    rec = dict({"id": pid, "code": c["code"], "course": c["title"], "exam": ex, "year": yr, "slot": slot, "path": dest,
                "view": view, "source": source, "added": now_ms(), "sha1": h}, **(extra or {}))
    known[pid] = rec
    hashes[h] = pid
    return rec


def download_url(url, dest):
    try:
        body, _ = fetch(url, timeout=90)
    except (urllib.error.URLError, TimeoutError, OSError):
        return False
    if body[:5] != b"%PDF-":
        return False
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest + ".part", "wb") as f:
        f.write(body)
    os.replace(dest + ".part", dest)
    return True


def own_hashes(cs):
    """your own papers' contents (cached by path and time), so nothing you have is fetched again."""
    cache = os.path.join(CACHE, "own-hashes.json")
    old, new = read_json(cache, {}) or {}, {}
    for c in cs:
        if not c["folder"]:
            continue
        for root, dirs, files in os.walk(os.path.join(c["folder"], "Exams & Question Papers")):
            dirs[:] = [d for d in dirs if d != "PYQs"]
            for f in files:
                if f.lower().endswith(".pdf"):
                    p = os.path.join(root, f)
                    m = os.path.getmtime(p)
                    new[p] = old[p] if old.get(p, {}).get("m") == m else {"m": m, "h": sha1_file(p)}
    write_json(cache, new)
    return {v["h"]: "own:" + k for k, v in new.items() if v.get("h")}


def from_mic(st, known, hashes, cs, force, budget):
    cache = os.path.join(CACHE, "manifest.json")
    manifest = read_json(cache)
    if force or not manifest or time.time() * 1000 - st.get("fetchedAt", 0) > 20 * 3600000:
        try:
            body, _ = fetch(PYQ_SITE + "/api/manuscripts", timeout=60)
            manifest = json.loads(body)
            os.makedirs(CACHE, exist_ok=True)
            write_json(cache, manifest)
        except (urllib.error.URLError, TimeoutError, OSError, ValueError) as e:
            if not manifest:
                raise RuntimeError("MIC PYQs: %s" % getattr(e, "reason", e))
    new = []
    for c in cs:
        for p in manifest:
            if (p.get("status") or "VERIFIED").upper() != "VERIFIED" or not paper_matches(c, p):
                continue
            pid = "mic:" + str(p.get("id"))
            if pid in known or budget[0] <= 0:
                continue
            fid = drive_id(p.get("downloadUrl"))
            if not fid:
                continue
            budget[0] -= 1
            time.sleep(1)
            ex, yr = exam_type(p.get("examType") or p.get("term")), str(p.get("academicYear") or "").replace("UnknownYear", "")
            r = add_paper(st, known, hashes, c, pid, ex, yr, p.get("slot") or "", "MIC PYQs (vhelp)", p.get("downloadUrl"),
                          lambda d: download_drive(fid, d), {"sourceCode": p.get("courseCode"), "sourceTitle": p.get("courseTitle")})
            if r:
                new.append(r)
    # each course's codes in the collection (old curriculum: BCSE302L for BACSE202)
    return new, {c["code"]: sorted({p.get("courseCode") for p in manifest if p.get("courseCode") and paper_matches(c, p)}) for c in cs}


def from_examcooker(st, known, hashes, cs, codes, budget):
    """ExamCooker (ACM-VIT): its public course pages, each paper page names its PDF."""
    new = []
    for c in cs:
        for code in sorted({c["code"]} | set(codes.get(c["code"], []))):
            try:
                body, _ = fetch(EXAMCOOKER + "/past_papers/" + urllib.parse.quote(code), timeout=40)
            except (urllib.error.URLError, TimeoutError, OSError):
                continue
            time.sleep(1)
            for pid_ in sorted(set(re.findall(r"/past_papers/%s/paper/([0-9a-f-]{36})" % re.escape(code), body.decode("utf-8", "replace")))):
                pid = "ec:" + pid_
                if pid in known or budget[0] <= 0:
                    continue
                try:
                    page, _ = fetch(EXAMCOOKER + "/past_papers/%s/paper/%s" % (code, pid_), timeout=40)
                except (urllib.error.URLError, TimeoutError, OSError):
                    continue
                txt = page.decode("utf-8", "replace").replace('\\"', '"')
                m = re.search(r'"fileUrl":"(https://[^"]+\.pdf)","fileName":"([^"]+)"', txt)
                if not m:
                    continue
                url, fname = m.group(1), m.group(2)
                ex, yr, slot = paper_fields(fname)
                budget[0] -= 1
                time.sleep(1)
                r = add_paper(st, known, hashes, c, pid, ex, yr, slot, "ExamCooker", EXAMCOOKER + "/past_papers/%s/paper/%s" % (code, pid_),
                              lambda d: download_url(url, d), {"sourceTitle": fname})
                if r:
                    new.append(r)
    return new


def from_github(st, known, hashes, cs, budget):
    new = []
    for repo, branch, label in GITHUB:
        try:
            body, _ = fetch("https://api.github.com/repos/%s/git/trees/%s?recursive=1" % (repo, branch), timeout=60)
            tree = [t["path"] for t in json.loads(body).get("tree", []) if t.get("type") == "blob" and t["path"].lower().endswith(".pdf")]
        except (urllib.error.URLError, TimeoutError, OSError, ValueError):
            continue
        for c in cs:
            for path in tree:
                if not folder_matches(c, path):
                    continue
                pid = "gh:%s:%s" % (repo, path)
                if pid in known or budget[0] <= 0:
                    continue
                ex, yr, slot = paper_fields(path)
                if ex == "Paper" and re.search(r"(?i)note|module|unit|lecture|ppt|book", path):
                    continue                                  # notes, not a question paper
                budget[0] -= 1
                url = "https://raw.githubusercontent.com/%s/%s/%s" % (repo, branch, urllib.parse.quote(path))
                r = add_paper(st, known, hashes, c, pid, ex, yr, slot, label + " (GitHub)", "https://github.com/%s/blob/%s/%s" % (repo, branch, urllib.parse.quote(path)),
                              lambda d: download_url(url, d), {"sourceTitle": path})
                if r:
                    new.append(r)
    return new


def cmd_pyq_sync(force=False):
    st = pyq_state()
    cs = [c for c in courses() if c["folder"]]
    known = {p["id"]: p for p in st.get("papers", [])}
    # a file that's gone (you deleted it) isn't fetched again; one that was never saved is retried
    hashes = own_hashes(cs)
    for p in known.values():
        if p.get("sha1"):
            hashes.setdefault(p["sha1"], p["id"])
        elif p.get("path") and os.path.exists(p["path"]):
            p["sha1"] = sha1_file(p["path"])
            hashes.setdefault(p["sha1"], p["id"])
    budget, new, errors = [120], [], []
    try:
        n, codes = from_mic(st, known, hashes, cs, force, budget)
        new += n
    except RuntimeError as e:
        errors.append(str(e))
        codes = {}
    for name, fn in (("ExamCooker", lambda: from_examcooker(st, known, hashes, cs, codes, budget)),
                     ("GitHub", lambda: from_github(st, known, hashes, cs, budget))):
        try:
            new += fn()
        except Exception as e:                               # one collection failing doesn't stop the others
            errors.append("%s: %s" % (name, e))
    st["fetchedAt"] = now_ms()
    st["papers"] = sorted(known.values(), key=lambda r: (r["code"], r.get("exam", ""), r.get("year", "")))
    write_json(os.path.join(STATE, "pyq.json"), st)
    out({"ok": True, "new": new, "errors": errors, "total": sum(1 for p in known.values() if p.get("path")),
         "more": budget[0] <= 0, "fetchedAt": st["fetchedAt"]})


def paper_fields(path):
    """exam, year, slot from a paper's name or folders ("…/CAT 1/… Slot C1 - 2022 …")."""
    low = path.replace("_", " ")
    tail = os.path.basename(low)
    ex = exam_type(tail) if re.search(r"(?i)\b(cat|fat)", tail) else exam_type(os.path.basename(os.path.dirname(low)))
    if ex not in ("CAT 1", "CAT 2", "FAT"):
        ex = "Model paper" if re.search(r"(?i)model", low) else "Paper"
    yr = (re.findall(r"\b(20\d\d)\b", tail) or [""])[0]
    slot = (re.findall(r"(?i)slot[ -]*([A-Z]{1,3}\d{1,2}(?:\+[A-Z]{1,3}\d{1,2})?)", tail) or [""])[0].upper()
    return ex, yr, slot


def cmd_pyq_list():
    st, prog = pyq_state(), progress()
    done = prog.get("pyqDone", {})
    own, keys = [], []
    for c in courses():
        if not c["folder"]:
            continue
        base = os.path.join(c["folder"], "Exams & Question Papers")
        for root, dirs, files in os.walk(base):
            dirs[:] = [d for d in dirs if d != "PYQs"]
            for f in files:
                path = os.path.join(root, f)
                # your own papers: the PDFs (photos and revision notes aren't papers to tick off)
                if not f.lower().endswith(".pdf") or re.search(r"(?i)revision|notes|solution|plan|syllabus", f):
                    continue
                ex, yr, slot = paper_fields(path)
                rec = {"code": c["code"], "course": c["title"], "exam": ex, "year": yr, "slot": slot, "path": path}
                if re.search(r"(?i)answer ?key|\bkey\b|scheme", f):
                    keys.append(rec)
                    continue
                oid = "own:" + path
                own.append(dict(rec, id=oid, source="your folder", done=oid in done, exists=True))
    sig = lambda p: (p["code"], p["exam"], p["year"], p["slot"])
    mine = {sig(p) for p in own if p["year"] and p["slot"]}
    papers = []
    for p in st.get("papers", []):
        # a downloaded copy of a paper you already had: keep the file, don't list it twice
        if p["year"] and p["slot"] and sig(p) in mine:
            continue
        papers.append(dict(p, done=p["id"] in done, exists=os.path.exists(p["path"])))
    allp = papers + own
    for p in allp:
        k = next((k for k in keys if sig(k) == sig(p)), None)
        if k:
            p["key"] = k["path"]
    out({"ok": True, "papers": allp, "fetchedAt": st.get("fetchedAt", 0)})


def cmd_done(pid, undo=False):
    prog = progress()
    d = prog.setdefault("pyqDone", {})
    if undo:
        d.pop(pid, None)
    else:
        d[pid] = now_ms()
    save_progress(prog)
    out({"ok": True})


# ── VTOP through your AmazeCC API ───────────────────────────────────────────

def amazecc():
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    import amazecc as A                                   # its login, keyring and session cache
    return A


def vtop_session(A, fresh=False):
    creds = A.secret_get()
    if not creds:
        raise RuntimeError("Sign in to VTOP first (Settings → AmazeCC)")
    s = A.session(API, creds, fresh=fresh)
    return {"cookies": s["cookies"], "csrf": s["csrf"], "authorizedID": s["authorizedID"]}


def course_page(A, base, fd):
    return (A.post(API, "course-page", dict(base, formData=fd), timeout=120) or {}).get("results") or {}


def lecture_plan(A, base, sem, c):
    """VTOP's course page: your class (your slot and teacher) → its lecture plan."""
    r1 = course_page(A, base, {"semesterSubId": sem})
    opts = [o for o in r1.get("selectOptions", {}).get("courseCode", []) if o["value"] and o["text"].upper().startswith(c["code"].upper())]
    emp = (re.findall(r"\d{4,}", c["faculty"]) or [""])[0]
    mine = set(c["slots"])
    rows = []
    for o in opts:
        r2 = course_page(A, base, {"semesterSubId": sem, "courseCode": o["value"]})
        for s in r2.get("selectOptions", {}).get("slotId", []):
            if not s["value"] or not (set(re.split(r"[+/ ]+", s["text"])) & mine):
                continue
            r3 = course_page(A, base, {"semesterSubId": sem, "courseCode": o["value"], "slotId": s["value"]})
            fac = [f["value"] for f in r3.get("selectOptions", {}).get("faculty", []) if f["value"] and (not emp or f["value"] == emp or emp in f["text"])]
            if not fac:
                continue
            r4 = course_page(A, base, {"semesterSubId": sem, "courseCode": o["value"], "slotId": s["value"], "faculty": fac[0]})
            row = ((r4.get("tables") or [{}])[0].get("rows") or [{}])[0]
            if not row.get("Class Id"):
                continue
            r5 = course_page(A, base, {"viewDetail": True, "semSubId": sem, "erpId": fac[0], "classId": row["Class Id"],
                                       "slotId": s["value"], "faculty": fac[0]})
            for t in r5.get("tables", []):
                if "Topic" in t.get("headers", []):
                    for x in t.get("rows", []):
                        d = x.get("Date") or ""
                        try:
                            iso = dt.datetime.strptime(d, "%d-%m-%Y").date().isoformat()
                        except ValueError:
                            continue
                        rows.append({"date": iso, "slot": (x.get("Day Order/ Slot") or "").split("/")[-1].strip(),
                                     "topic": re.sub(r"\s+", " ", x.get("Topic") or "").strip(), "classId": row["Class Id"],
                                     "kind": "lab" if o["text"].rstrip().endswith(("LO", "ELA", "LA")) else "theory"})
            break
    rows.sort(key=lambda r: r["date"])
    return rows


def save_syllabus(c):
    """The course's syllabus PDF from VTOP's curriculum page, into <course>/Syllabus/."""
    if not c["folder"]:
        return None
    A = amazecc()
    base = vtop_session(A)
    req = urllib.request.Request(API + "/api/curriculum/syllabus", data=json.dumps(dict(base, courseCode=c["code"])).encode(),
                                 headers={"Content-Type": "application/json"}, method="POST")
    try:
        with urllib.request.urlopen(req, timeout=120) as r:
            body = r.read()
    except (urllib.error.URLError, TimeoutError, OSError):
        return None
    # one PDF, or a zip of them (a course with theory and lab: one syllabus each)
    files = []
    if body[:5] == b"%PDF-":
        files.append(("%s Syllabus (VTOP).pdf" % c["code"], body))
    elif body[:4] == b"PK\x03\x04":
        import io, zipfile
        try:
            with zipfile.ZipFile(io.BytesIO(body)) as z:
                for info in z.infolist():
                    if info.filename.lower().endswith(".pdf") and info.file_size < 30 * 2**20:
                        data = z.read(info)
                        if data[:5] == b"%PDF-":
                            # BACSE106_OPERATING-SYSTEMS_ELA_1.0_80_BACSE106.pdf → "BACSE106 Syllabus ELA (VTOP).pdf"
                            kind = (re.findall(r"_(E?TH|E?LA|LO|TH|SS)_", info.filename) or [""])[0]
                            files.append(("%s Syllabus%s (VTOP).pdf" % (c["code"], " " + kind if kind else ""), data))
        except zipfile.BadZipFile:
            return None
    saved = None
    for name, data in files:
        dest = os.path.join(c["folder"], "Syllabus", safe_name(name))
        if not (os.path.exists(dest) and open(dest, "rb").read() == data):
            os.makedirs(os.path.dirname(dest), exist_ok=True)
            with open(dest, "wb") as f:
                f.write(data)
        saved = dest
    return saved


def cmd_lectures_sync():
    A = amazecc()
    try:
        base = vtop_session(A)
    except Exception as e:
        return out({"ok": False, "error": str(e)})
    sem = A.default_semester()
    st = read_json(os.path.join(STATE, "lectures.json"), {}) or {}
    errors, syllabi = [], []
    for c in courses():
        try:
            rows = lecture_plan(A, base, sem, c)
        except Exception as e:                            # one course failing doesn't stop the rest
            errors.append("%s: %s" % (c["code"], e))
            continue
        if rows:
            st[c["code"]] = {"title": c["title"], "rows": rows, "fetchedAt": now_ms()}
        elif c["code"] not in st:
            # nothing for your slot and teacher: say so, don't show an empty plan
            st[c["code"]] = {"title": c["title"], "rows": [], "fetchedAt": now_ms(), "missing": "Your teacher hasn't published a lecture plan on VTOP"}
        try:
            p = save_syllabus(c)
            if p:
                syllabi.append(p)
        except Exception as e:
            errors.append("%s syllabus: %s" % (c["code"], e))
    write_json(os.path.join(STATE, "lectures.json"), st)
    out({"ok": not errors or bool(st), "courses": {k: len(v["rows"]) for k, v in st.items()}, "syllabi": syllabi, "errors": errors})


def lectures():
    return read_json(os.path.join(STATE, "lectures.json"), {}) or {}


def cmd_missed():
    """Absent days (attended stayed the same while the total went up) → that day's topic."""
    hist = (read_json(os.path.join(LSTATE, "amazecc-history.json"), {}) or {}).get("attendance", {})
    lec, cs = lectures(), courses()
    by_id = {i: c for c in cs for i in c["ids"]}
    days = sorted(hist)
    missed = []
    for a, b in zip(days, days[1:]):
        for cid, cur in hist[b].items():
            prev = hist[a].get(cid)
            if not prev or cid not in by_id:
                continue
            gone = (cur[1] - prev[1]) - (cur[0] - prev[0])
            if gone <= 0:
                continue
            c = by_id[cid]
            # the class(es) between the two snapshots: (a, b]
            rows = [r for r in lec.get(c["code"], {}).get("rows", []) if a < r["date"] <= b and r.get("classId") == cid]
            missed.append({"code": c["code"], "course": c["title"], "from": a, "to": b, "count": gone,
                           "topics": [r["topic"] for r in rows][-gone:] if rows else []})
    out({"ok": True, "missed": missed, "since": days[0] if days else None})


def cmd_attendance():
    snap = snapshot()
    days = {d["date"]: d for d in snap.get("days", [])}
    today = dt.date.today()
    instr = sorted(d for d, x in days.items() if x.get("kind") == "instructional")
    last = instr[-1] if instr else None
    names = ["MON", "TUE", "WED", "THU", "FRI", "SAT", "SUN"]
    left = {}
    d = today
    while last and d.isoformat() <= last:
        x = days.get(d.isoformat())
        if x and x.get("kind") == "instructional":
            # a Saturday that follows another day's timetable ("Day Order")
            order = x.get("order")
            wd = names[d.weekday()] if not order else str(order).upper()[:3]
            for cls in snap.get("week", {}).get(wd, []):
                left[cls["id"]] = left.get(cls["id"], 0) + 1
        d += dt.timedelta(days=1)
    rows = []
    for c in snap.get("courses", []):
        a, t, n = c.get("attended") or 0, c.get("total") or 0, left.get(c["id"], 0)
        # largest k with (a + n - k) / (t + n) ≥ 0.75
        k = int((a + n) - 0.75 * (t + n))
        rows.append({"id": c["id"], "code": c["code"], "title": c["title"], "kind": c.get("kind"), "pct": c.get("pct"),
                     "attended": a, "total": t, "left": n, "canMiss": max(-1, min(n, k)) if k >= 0 else -1,
                     "needAll": k < 0, "endPct": round(100 * (a + n) / (t + n), 1) if t + n else None})
    out({"ok": True, "lastDay": last, "courses": rows})


def words(s):
    stop = {"and", "the", "of", "to", "in", "for", "on", "with", "a", "an", "using", "its", "from", "into", "by", "or", "vs"}
    return [w for w in re.findall(r"[a-z][a-z0-9+#-]{2,}", s.lower()) if w not in stop]


def pdf_text(path, ocr=True):
    try:
        r = subprocess.run(["pdftotext", "-q", "-layout", path, "-"], capture_output=True, text=True, timeout=60)
        text = r.stdout
    except (OSError, subprocess.TimeoutExpired):
        text = ""
    if len(text.strip()) > 80 or not ocr:
        return text
    # a scanned paper: OCR its first 6 pages once (tesseract), cached by file and mtime
    import hashlib
    key = hashlib.sha1(("%s:%s" % (path, os.path.getmtime(path))).encode()).hexdigest()
    cached = os.path.join(CACHE, "ocr", key + ".txt")
    if os.path.exists(cached):
        return open(cached, errors="replace").read()
    import tempfile
    pages = []
    with tempfile.TemporaryDirectory() as tmp:
        try:
            subprocess.run(["pdftoppm", "-r", "200", "-l", "6", "-png", path, os.path.join(tmp, "p")], capture_output=True, timeout=180)
            for img in sorted(glob.glob(os.path.join(tmp, "p*.png"))):
                pages.append(subprocess.run(["tesseract", img, "-", "-l", "eng"], capture_output=True, text=True, timeout=120).stdout)
        except (OSError, subprocess.TimeoutExpired):
            return text
    text = "\n".join(pages)
    os.makedirs(os.path.dirname(cached), exist_ok=True)
    with open(cached, "w") as f:
        f.write(text)
    return text


def cmd_topics(code):
    rows = lectures().get(code, {}).get("rows", [])
    papers = [p for p in pyq_state().get("papers", []) if p["code"] == code and os.path.exists(p["path"])]
    texts = [(p, pdf_text(p["path"]).lower()) for p in papers]
    texts = [(p, t) for p, t in texts if t.strip()]
    res = []
    for r in rows:
        if r.get("kind") == "lab":
            continue
        for part in re.split(r"\s+[-–]\s+|;|,(?![^()]*\))", r["topic"]):
            kw = words(part)
            if not kw:
                continue
            hits = [p for p, t in texts if sum(1 for w in kw if w in t) >= max(1, (len(kw) + 1) // 2)]
            res.append({"topic": part.strip(), "date": r["date"], "papers": len(hits),
                        "exams": sorted({p["exam"] for p in hits})})
    seen, uniq = set(), []
    for x in sorted(res, key=lambda x: -x["papers"]):
        k = norm(x["topic"])
        if k and k not in seen:
            seen.add(k)
            uniq.append(x)
    out({"ok": True, "code": code, "papersRead": len(texts), "papersTotal": len(papers), "topics": uniq[:60]})


# ── search index ────────────────────────────────────────────────────────────

def walk_academics():
    for root, dirs, files in os.walk(ACAD):
        # a Unity project: its Assets are code and art, not study material
        if "ProjectSettings" in dirs and "Assets" in dirs:
            dirs[:] = []
            continue
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS and not d.startswith(".")]
        for f in files:
            if f.startswith(".") or os.path.splitext(f)[1].lower() in SKIP_EXT:
                continue
            yield os.path.join(root, f)


def cmd_index(quiet=False):
    p = os.path.join(CACHE, "index.json")
    idx = read_json(p, {}) or {}
    fresh, live = 0, set()
    for path in walk_academics():
        ext = os.path.splitext(path)[1].lower()
        if ext not in TEXT_EXT and ext != ".pdf":
            continue
        live.add(path)
        try:
            m = os.path.getmtime(path)
        except OSError:
            continue
        # unchanged — unless it's a question paper that had no text (a scan, OCR it now)
        if idx.get(path, {}).get("m") == m and (idx[path]["t"].strip() or "Exams & Question Papers" not in path):
            continue
        # (OCR only for question papers: slides are usually text already, and OCR is slow)
        text = pdf_text(path, ocr="Exams & Question Papers" in path) if ext == ".pdf" else open(path, errors="replace").read(400000)
        # photos turned into text by `study.py ocr` sit next to them as .ocr.txt
        idx[path] = {"m": m, "t": re.sub(r"\s+", " ", text)[:200000]}
        fresh += 1
    for path in list(idx):
        if path not in live:
            del idx[path]
    os.makedirs(CACHE, exist_ok=True)
    write_json(p, idx)
    if not quiet:
        out({"ok": True, "files": len(idx), "updated": fresh})


def course_for_path(path):
    rel = os.path.relpath(path, ACAD).split(os.sep)
    return rel[1] if len(rel) > 2 else ""


def cmd_search(q):
    q = q.strip()
    if len(q) < 2:
        return out({"ok": True, "results": []})
    terms = [t for t in q.lower().split() if t]
    res = []
    for path in walk_academics():
        name = os.path.basename(path).lower()
        if all(t in name for t in terms):
            res.append({"path": path, "name": os.path.basename(path), "course": course_for_path(path), "kind": "name", "snippet": ""})
    named = {r["path"] for r in res}
    idx = read_json(os.path.join(CACHE, "index.json"), {}) or {}
    for path, e in idx.items():
        if path in named:
            continue
        low = e["t"].lower()
        if all(t in low for t in terms):
            i = low.find(terms[0])
            snip = e["t"][max(0, i - 60): i + 120].strip()
            res.append({"path": path, "name": os.path.basename(path), "course": course_for_path(path), "kind": "text",
                        "snippet": snip, "hits": sum(low.count(t) for t in terms)})
    res.sort(key=lambda r: (r["kind"] != "name", -r.get("hits", 0)))
    out({"ok": True, "results": res[:40], "indexed": len(idx)})


# ── filing ──────────────────────────────────────────────────────────────────

KEYS = [("Exams & Question Papers", r"\b(cat|fat|qp|question ?paper|pyq|exam|midsem|endsem)(\d|\b)"),
        ("Assignments & Labs", r"\b(da|lab|assignment|record|experiment|exercise|worksheet|project|report)(\d|\b)"),
        ("Syllabus", r"\b(syllabus|curriculum|course ?plan)\b"),
        ("Revision & Cheat Sheets", r"\b(cheat|revision|summary|formula|notes ?short)\b"),
        ("Practice Problems", r"\b(practice|problems?|tutorial|questions?)\b"),
        ("Lecture Slides & Notes", r"\b(module|mod|unit|lecture|slides?|ppt|notes?|chapter|ch)(\d|\b)")]


# a standard subfolder → the one this course actually has ("Projects & Labs" for labs…)
SUB_WORDS = {"Lecture Slides & Notes": ("lecture", "notes", "study guide", "materials", "slides"),
             "Exams & Question Papers": ("exam", "question"),
             "Assignments & Labs": ("assignment", "lab", "project"),
             "Revision & Cheat Sheets": ("revision", "cheat"),
             "Syllabus": ("syllabus",), "Practice Problems": ("practice",)}


def existing_sub(folder, sub):
    try:
        have = [d for d in os.listdir(folder) if os.path.isdir(os.path.join(folder, d))]
    except OSError:
        return sub
    if sub in have:
        return sub
    return next((d for d in have if any(w in d.lower() for w in SUB_WORDS.get(sub, ()))), sub)


def cmd_classify(path):
    name = os.path.basename(path)
    low = name.lower().replace("_", " ").replace("-", " ")
    best, score = None, 0
    for c in courses():
        s = 0
        if c["code"].lower() in low.replace(" ", ""):
            s += 10
        # distinctive title words ("java", "database"), not the generic ones
        generic = {"systems", "system", "using", "fundamentals", "introduction", "skills", "practice", "problem", "solving", "models"}
        # (your folder's own name counts too: VTOP's "Qualitative and Quantitative…" is your "Soft Skills")
        fname = re.sub(r"^[A-Z0-9]+\s*-\s*", "", os.path.basename(c["folder"] or ""))
        tw = sorted({w for w in words(c["title"] + " " + fname) if len(w) > 3 and w not in generic})
        s += sum(3 for w in tw if re.search(r"\b%s" % re.escape(w), low))
        # abbreviations: the title's initials (OS) and the one in your folder name ("(MOC)", "(DBMS)")
        abbrs = {"".join(w[0] for w in re.findall(r"[A-Za-z]+", c["title"]) if w[0].isupper()).lower()}
        # ("AR-VR" in the folder; the file name may say "AR-VR", "AR VR" or "ARVR")
        abbrs |= {v for a in re.findall(r"\(([A-Za-z-]{2,8})\)", os.path.basename(c["folder"] or "")) for v in (a.lower().replace("-", ""), a.lower().replace("-", " "))}
        if any(len(a) >= 2 and re.search(r"\b%s(?=\b|\d)" % re.escape(a), low) for a in abbrs):
            s += 6
        if s > score:
            best, score = c, s
    sub = next((s for s, rx in KEYS if re.search(rx, low)), "Lecture Slides & Notes")
    ok = best and score >= 3
    if ok:
        sub = existing_sub(best["folder"], sub)
    out({"ok": True, "file": path, "code": best["code"] if ok else None,
         "course": best["title"] if ok else None, "folder": best["folder"] if ok else None,
         "sub": sub, "confidence": min(1, score / 10)})


def cmd_file(path, code, sub):
    c = course_of(code)
    if not c or not c["folder"]:
        return out({"ok": False, "error": "No folder for " + code})
    # a standard subfolder, or one this course already has — never a path elsewhere
    if "/" in sub or sub.startswith(".") or (sub not in SUBS and not os.path.isdir(os.path.join(c["folder"], sub))):
        return out({"ok": False, "error": "Unknown subfolder"})
    if not os.path.isfile(path):
        return out({"ok": False, "error": "No such file"})
    dest = unique_path(os.path.join(c["folder"], sub, os.path.basename(path)))
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    shutil.move(path, dest)
    out({"ok": True, "path": dest})


def cmd_recent(n=12):
    seen = {}
    try:
        x = open(HOME + "/.local/share/recently-used.xbel", errors="replace").read()
        for href, mod in re.findall(r'href="file://([^"]+)"[^>]*modified="([^"]+)"', x):
            p = urllib.parse.unquote(href)
            if p.startswith(ACAD + "/") and os.path.isfile(p):
                t = dt.datetime.fromisoformat(mod.replace("Z", "+00:00")).timestamp()
                seen[p] = max(seen.get(p, 0), t)
    except (OSError, ValueError):
        pass
    cutoff = time.time() - 21 * 86400
    for p in walk_academics():
        try:
            m = os.path.getmtime(p)
        except OSError:
            continue
        if m > cutoff and os.path.splitext(p)[1].lower() in (TEXT_EXT | {".pdf", ".pptx", ".docx", ".png", ".jpg"}):
            seen[p] = max(seen.get(p, 0), m)
    items = sorted(seen.items(), key=lambda kv: -kv[1])[:n]
    out({"ok": True, "files": [{"path": p, "name": os.path.basename(p), "course": course_for_path(p), "at": int(t * 1000)} for p, t in items]})


def cmd_newsem(name, apply=False):
    cs = courses()
    if not re.fullmatch(r"[A-Za-z0-9 ()&,.-]{3,60}", name or ""):
        return out({"ok": False, "error": "A plain name, e.g. \"Semester 4 - Winter 2026-27\""})
    root = os.path.join(ACAD, name + " (Current)")
    plan = [os.path.join(root, "%s - %s" % (c["code"], safe_name(c["title"])), s) for c in cs for s in SUBS]
    plan.append(os.path.join(root, "Semester Administration"))
    old = current_semester_dir()
    res = {"ok": True, "root": root, "folders": plan, "renameOld": old and old != root and old.endswith(" (Current)")}
    if apply:
        for p in plan:
            os.makedirs(p, exist_ok=True)
        if res["renameOld"]:
            os.rename(old, old[: -len(" (Current)")])
        res["applied"] = True
    out(res)


def cmd_backup():
    r = {"ok": True, "repo": os.path.isdir(os.path.join(ACAD, ".git"))}
    if not r["repo"]:
        return out(r)
    def git(*a):
        return subprocess.run(["git", "-c", "core.hooksPath=/dev/null", "-C", ACAD] + list(a), capture_output=True, text=True, timeout=60).stdout.strip()
    try:
        last = git("log", "-1", "--format=%ct%x09%s")
        ts, subj = (last.split("\t", 1) + [""])[:2] if last else ("0", "")
        r.update(lastCommit=int(ts or 0) * 1000, subject=subj)
        size = subprocess.run(["du", "-sb", os.path.join(ACAD, ".git")], capture_output=True, text=True, timeout=60).stdout.split()
        r["gitBytes"] = int(size[0]) if size else 0
        r["pending"] = len([l for l in git("status", "--porcelain").splitlines() if l.strip()])
    except (OSError, subprocess.TimeoutExpired, ValueError):
        r["ok"] = False
    log = os.path.join(ACAD, ".backup.log")
    if os.path.exists(log):
        r["logAt"] = int(os.path.getmtime(log) * 1000)
        r["logTail"] = open(log, errors="replace").read()[-400:]
        r["logFailed"] = bool(re.search(r"(?i)\b(error|fatal|failed|rejected)\b", r["logTail"]))
    r["stale"] = r.get("lastCommit", 0) < (time.time() - 30 * 3600) * 1000
    out(r)


def cmd_ocr(folder):
    folder = os.path.abspath(folder)
    if not folder.startswith(ACAD + "/"):
        return out({"ok": False, "error": "Only folders inside Academics"})
    done = 0
    for root, _, files in os.walk(folder):
        for f in files:
            if not f.lower().endswith((".png", ".jpg", ".jpeg")):
                continue
            img = os.path.join(root, f)
            txt = img + ".ocr.txt"
            if os.path.exists(txt) and os.path.getmtime(txt) >= os.path.getmtime(img):
                continue
            try:
                r = subprocess.run(["tesseract", img, "-", "-l", "eng"], capture_output=True, text=True, timeout=120)
            except (OSError, subprocess.TimeoutExpired):
                continue
            with open(txt, "w") as fh:
                fh.write(r.stdout)
            done += 1
    out({"ok": True, "done": done})


# ── flashcards (spaced repetition) ──────────────────────────────────────────

def clean_md(t):
    t = re.sub(r"[\U0001F300-\U0001FAFF\u2600-\u27BF]", "", t)        # emoji in headings
    t = re.sub(r"^\s*\d+[.)]\s*", "", t)                                # "1. " numbering
    return re.sub(r"\s+", " ", t).strip().strip(":").strip()


def parse_cards(text, src):
    cards = []
    for q, a in re.findall(r"(?mi)^\s*Q[:.]\s*(.+)\n\s*A[:.]\s*(.+)$", text):
        cards.append((q, a))
    # definitions: "- **Term:** text", "**Term**: text", "- **Term** — text"
    # (line by line, so a generic term — "Input", "Requirement" — takes its section's name)
    section = ""
    plain = {"input", "output", "requirement", "requirements", "steps", "step", "time", "space", "complexity", "result",
             "idea", "method", "algorithm", "condition", "conditions", "rule", "rules", "use", "purpose", "goal", "key idea"}
    for line in text.splitlines():
        h = re.match(r"^#{1,4}\s+(.+)", line)
        if h:
            section = clean_md(h.group(1))
            continue
        m = re.match(r"^\s*(?:[-*]\s+)?\*\*([^*\n]{2,80}?)[:：]?\*\*\s*[:—–-]?\s*(\S.{8,400})$", line)
        if not m:
            continue
        term = clean_md(m.group(1))
        if not term or term.lower().startswith(("note", "example", "tip", "warning", "answer")):
            continue
        q = ("%s — %s?" % (section, term)) if term.lower() in plain and section else ("What is " + term + "?")
        cards.append((q, m.group(2).strip()))
    # sections: "## Heading" + its first lines; a generic heading takes its parent's
    # name ("Theorem" under "Pumping Lemma" → "Pumping Lemma: Theorem")
    parent = ""
    for line_h, body in re.findall(r"(?m)^(#{1,4}\s+.{3,90})\n+((?:(?!#).*\n?){1,8})", text):
        level, h = len(line_h) - len(line_h.lstrip("#")), clean_md(line_h.lstrip("#"))
        if level <= 2:
            parent = h
        b = re.sub(r"\s+", " ", body).strip()
        if level < 2 or not (20 < len(b) < 700) or b.count("|") > 6:      # (not tables: they read badly on a card)
            continue
        if b.lstrip().startswith(("* **", "- **")) and b.count("**") >= 4:
            continue                                                       # a list of definitions: carded one by one above
        generic = len(h.split()) <= 2 and h.lower() in {"theorem", "definition", "definitions", "proof", "example", "examples", "key points", "summary", "formula", "formulas", "notes", "overview"}
        q = (parent + ": " + h) if generic and parent and parent != h else h
        cards.append((q + " — explain.", b))
    seen, res = set(), []
    for q, a in cards:
        k = norm(q)
        if k and k not in seen:
            seen.add(k)
            cid = "%s#%s" % (os.path.basename(src), k[:40])
            res.append({"id": cid, "q": q.strip(), "a": a.strip(), "src": src})
    return res


def cmd_cards(code):
    c = course_of(code)
    if not c or not c["folder"]:
        return out({"ok": False, "error": "No folder for " + code})
    deck = []
    base = os.path.join(c["folder"], "Revision & Cheat Sheets")
    for path in glob.glob(os.path.join(base, "**", "*.md"), recursive=True) + glob.glob(os.path.join(c["folder"], "Exams & Question Papers", "**", "*.md"), recursive=True):
        try:
            deck += parse_cards(open(path, errors="replace").read(), path)
        except OSError:
            pass
    fj = os.path.join(base, "flashcards.json")              # Halo-made cards: [{q, a}]
    for i, x in enumerate(read_json(fj, []) or []):
        if isinstance(x, dict) and x.get("q") and x.get("a"):
            deck.append({"id": "halo#%d#%s" % (i, norm(x["q"])[:30]), "q": x["q"], "a": x["a"], "src": fj})
    rev = progress().get("cards", {})
    today = now_ms()
    for card in deck:
        s = rev.get(card["id"], {})
        card["due"] = s.get("due", 0)
        card["reps"] = s.get("reps", 0)
    due = [x for x in deck if x["due"] <= today]
    due.sort(key=lambda x: (x["reps"] > 0, x["due"]))
    out({"ok": True, "code": code, "total": len(deck), "due": len(due), "cards": due[:40], "flashFile": fj})


def cmd_review(code, cid, grade):
    grade = max(0, min(3, int(grade)))
    prog = progress()
    cards = prog.setdefault("cards", {})
    s = cards.get(cid, {"ease": 2.5, "interval": 0, "reps": 0})
    if grade == 0:
        s["interval"], s["reps"] = 0, 0
        s["due"] = now_ms() + 10 * 60000                  # again in 10 minutes
    else:
        s["ease"] = max(1.3, s["ease"] + (-0.15, 0, 0.1)[grade - 1])
        s["interval"] = 1 if s["reps"] == 0 else 3 if s["reps"] == 1 else round(s["interval"] * s["ease"] * (0.8, 1, 1.3)[grade - 1])
        s["reps"] += 1
        s["due"] = now_ms() + s["interval"] * 86400000
    cards[cid] = s
    save_progress(prog)
    out({"ok": True, "next": s["due"]})


def cmd_log(code, minutes):
    prog = progress()
    prog.setdefault("sessions", []).append({"code": code, "at": now_ms(), "minutes": int(minutes)})
    prog["sessions"] = prog["sessions"][-1000:]
    save_progress(prog)
    out({"ok": True})


def cmd_stats():
    s = progress().get("sessions", [])
    week = now_ms() - 7 * 86400000
    per, total = {}, {}
    for x in s:
        total[x["code"]] = total.get(x["code"], 0) + x["minutes"]
        if x["at"] >= week:
            per[x["code"]] = per.get(x["code"], 0) + x["minutes"]
    out({"ok": True, "week": per, "total": total})


def cmd_module(code, n, undo=False):
    prog = progress()
    m = prog.setdefault("modules", {}).setdefault(code, {})
    if undo:
        m.pop(str(n), None)
    else:
        m[str(n)] = now_ms()
    save_progress(prog)
    out({"ok": True, "modules": m})


# ── campus (public pages of your AmazeCC API) ───────────────────────────────

def cmd_events():
    try:
        body, _ = fetch(API + "/api/events", timeout=60)
        evs = json.loads(body)
    except Exception as e:
        return out({"ok": False, "error": "events: %s" % e})
    today = dt.date.today().isoformat()
    seen, res = set(), []
    for e in evs if isinstance(evs, list) else []:
        if (e.get("date") or "") < today or e.get("eid") in seen:
            continue
        seen.add(e.get("eid"))
        res.append({"id": e.get("eid"), "title": html.unescape(e.get("title") or ""), "date": e.get("date"),
                    "where": e.get("location") or "", "type": e.get("type") or "", "price": e.get("price") or ""})
    res.sort(key=lambda e: e["date"])
    write_json(os.path.join(STATE, "events.json"), {"at": now_ms(), "events": res})
    out({"ok": True, "events": res[:40]})


def cmd_buses(stop=""):
    try:
        body, _ = fetch(API + "/api/buses", timeout=60)
        bs = json.loads(body).get("buses", [])
    except Exception as e:
        return out({"ok": False, "error": "buses: %s" % e})
    s = norm(stop)
    res = [{"route": b.get("route"), "type": b.get("type"), "stops": b.get("boardingPoints") or []} for b in bs
           if not s or s in norm(b.get("route")) or any(s in norm(p) for p in b.get("boardingPoints") or [])]
    out({"ok": True, "buses": res})


# ── overview: one call for the app ─────────────────────────────────────────

def capture(fn, *a):
    import io
    old, buf = sys.stdout, io.StringIO()
    sys.stdout = buf
    try:
        fn(*a)
    finally:
        sys.stdout = old
    try:
        return json.loads(buf.getvalue() or "{}")
    except ValueError:
        return {}


def cmd_overview():
    cs = courses()
    papers = capture(cmd_pyq_list).get("papers", [])
    lec = lectures()
    prog = progress()
    today = dt.date.today().isoformat()
    for c in cs:
        mine = [p for p in papers if p["code"] == c["code"]]
        c["papers"] = len(mine)
        c["papersDone"] = sum(1 for p in mine if p["done"])
        rows = [r for r in lec.get(c["code"], {}).get("rows", []) if r.get("kind") != "lab"]
        c["lectures"] = len(rows)
        c["lecturesDone"] = sum(1 for r in rows if r["date"] <= today)
        c["lastTopic"] = next((r["topic"] for r in reversed(rows) if r["date"] <= today), "")
        c["modules"] = prog.get("modules", {}).get(c["code"], {})
        c["subs"] = sorted(d for d in os.listdir(c["folder"]) if os.path.isdir(os.path.join(c["folder"], d))) if c["folder"] else []
    st = prog.get("sessions", [])
    week = now_ms() - 7 * 86400000
    for c in cs:
        c["weekMinutes"] = sum(x["minutes"] for x in st if x["code"] == c["code"] and x["at"] >= week)
    out({"ok": True, "courses": cs, "academics": ACAD, "semesterDir": current_semester_dir(),
         "pyqFetchedAt": pyq_state().get("fetchedAt", 0), "lecturesAt": max([v.get("fetchedAt", 0) for v in lec.values()] or [0])})


def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__)
        sys.exit(2)
    cmd, rest = a[0], a[1:]
    flag = lambda f: f in rest and (rest.remove(f) or True)
    try:
        if cmd == "courses":
            out({"ok": True, "courses": courses()})
        elif cmd == "pyq" and rest[:1] == ["sync"]:
            cmd_pyq_sync(force="--force" in rest)
        elif cmd == "pyq" and rest[:1] == ["list"]:
            cmd_pyq_list()
        elif cmd == "done" and rest:
            undo = flag("--undo")
            cmd_done(rest[0], undo)
        elif cmd == "lectures" and rest[:1] == ["sync"]:
            cmd_lectures_sync()
        elif cmd == "missed":
            cmd_missed()
        elif cmd == "attendance":
            cmd_attendance()
        elif cmd == "topics" and rest:
            cmd_topics(rest[0].upper())
        elif cmd == "index":
            cmd_index()
        elif cmd == "search":
            cmd_search(" ".join(rest))
        elif cmd == "classify" and rest:
            cmd_classify(rest[0])
        elif cmd == "file" and len(rest) == 3:
            cmd_file(rest[0], rest[1], rest[2])
        elif cmd == "recent":
            cmd_recent(int(rest[0]) if rest else 12)
        elif cmd == "newsem" and rest:
            apply = flag("--apply")
            cmd_newsem(" ".join(rest), apply)
        elif cmd == "backup":
            cmd_backup()
        elif cmd == "ocr" and rest:
            cmd_ocr(rest[0])
        elif cmd == "cards" and rest:
            cmd_cards(rest[0].upper())
        elif cmd == "review" and len(rest) == 3:
            cmd_review(rest[0], rest[1], rest[2])
        elif cmd == "log" and len(rest) == 2:
            cmd_log(rest[0].upper(), rest[1])
        elif cmd == "stats":
            cmd_stats()
        elif cmd == "module" and len(rest) >= 2:
            undo = flag("--undo")
            cmd_module(rest[0].upper(), rest[1], undo)
        elif cmd == "events":
            cmd_events()
        elif cmd == "buses":
            cmd_buses(" ".join(rest))
        elif cmd == "overview":
            cmd_overview()
        else:
            print(__doc__)
            sys.exit(2)
    except KeyboardInterrupt:
        sys.exit(130)


if __name__ == "__main__":
    main()
