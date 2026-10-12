#!/usr/bin/env python3
"""notes.py — Lumen Notes: a folder of plain Markdown files.

The folder (default ~/Notes) is the whole store: one note per .md file, so
Syncthing can carry it to your phone and any Markdown app (Obsidian, Markor…)
can open it. Lumen keeps only small preferences (pins) to itself.

  notes.py [--dir D] ensure             create the folder, its .stignore, and copy the
                                        planner's old scratchpad (state/lumen/notes.md) in
  notes.py [--dir D] list               JSON [{file, title, preview, mtime, words}], newest first
  notes.py [--dir D] search <query>     JSON [{file, title, line, text}] (case-insensitive)
  notes.py [--dir D] new [title]        create "<title>.md" (unique), print its file name
  notes.py [--dir D] rename <file> <title>   rename the file, print the new name
  notes.py [--dir D] trash <file>       move it to .trash/ (kept locally, never synced)
  notes.py [--dir D] restore            JSON list of trashed notes; `restore <name>` puts one back
  notes.py [--dir D] watch              one line per change in the folder (inotifywait), for live lists
"""
import argparse
import datetime as dt
import json
import os
import re
import shutil
import subprocess
import sys

STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "lumen")
SCRATCH = "Scratchpad.md"
STIGNORE = "// Lumen Notes: what Syncthing leaves on this computer\n.trash\n.stversions\n*.tmp\n.~*\n"
MAX_PREVIEW = 140


def out(obj):
    print(json.dumps(obj, separators=(",", ":"), ensure_ascii=False))


def safe(dirpath, name):
    """A note's path, refusing anything that would leave the folder."""
    name = os.path.basename(name or "")
    if not name.endswith(".md") or name.startswith("."):
        sys.exit("not a note: %r" % name)
    return os.path.join(dirpath, name)


def slug(title):
    t = re.sub(r"[\\/:*?\"<>|\x00-\x1f]", " ", title or "").strip().strip(".")
    t = re.sub(r"\s+", " ", t)[:80].strip()
    return t or "Untitled"


def unique(dirpath, stem):
    name, n = stem + ".md", 2
    while os.path.exists(os.path.join(dirpath, name)):
        name = "%s %d.md" % (stem, n)
        n += 1
    return name


def describe(path):
    try:
        with open(path, encoding="utf-8", errors="replace") as f:
            text = f.read(20000)
    except OSError:
        return None
    lines = [l.strip() for l in text.splitlines()]
    body = [l for l in lines if l]
    title = ""
    for l in body[:5]:
        m = re.match(r"^#{1,6}\s+(.+)$", l)
        if m:
            title = m.group(1).strip()
            break
    stem = os.path.basename(path)[:-3]
    rest = [l for l in body if not re.match(r"^#{1,6}\s+" + re.escape(title) + r"$", l)] if title else body
    preview = " ".join(re.sub(r"^([-*] \[[ xX]\]|[#>*\-+]|\d+\.)\s*", "", l) for l in rest)
    preview = re.sub(r"[*_`~]{1,3}", "", preview)
    tasks = len(re.findall(r"^\s*[-*] \[ \]", text, re.M))
    return {
        "file": os.path.basename(path),
        "title": title or stem,
        "preview": preview[:MAX_PREVIEW],
        "mtime": int(os.path.getmtime(path) * 1000),
        "words": len(re.findall(r"\S+", text)),
        "open": tasks,
    }


def cmd_ensure(a):
    os.makedirs(a.dir, exist_ok=True)
    ign = os.path.join(a.dir, ".stignore")
    if not os.path.exists(ign):
        with open(ign, "w") as f:
            f.write(STIGNORE)
    old = os.path.join(STATE, "notes.md")
    new = os.path.join(a.dir, SCRATCH)
    moved = False
    if not os.path.exists(new):
        if os.path.exists(old) and os.path.getsize(old) > 0:
            with open(old, encoding="utf-8", errors="replace") as f:
                text = f.read()
            with open(new, "w", encoding="utf-8") as f:
                f.write(text if text.lstrip().startswith("#") else "# Scratchpad\n\n" + text)
            # Copied, not moved: an older Lumen still running reads the old file
            moved = True
        else:
            with open(new, "w", encoding="utf-8") as f:
                f.write("# Scratchpad\n\n")
    out({"ok": True, "dir": a.dir, "scratch": new, "moved": moved})


def notes(dirpath):
    try:
        names = os.listdir(dirpath)
    except OSError:
        return []
    return [os.path.join(dirpath, n) for n in names if n.endswith(".md") and not n.startswith(".")]


def cmd_list(a):
    items = [d for d in (describe(p) for p in notes(a.dir)) if d]
    items.sort(key=lambda d: -d["mtime"])
    out(items)


def cmd_search(a):
    q = (a.query or "").strip().lower()
    hits = []
    if not q:
        out(hits)
        return
    for p in notes(a.dir):
        d = describe(p)
        if not d:
            continue
        name_hit = q in d["title"].lower()
        try:
            with open(p, encoding="utf-8", errors="replace") as f:
                lines = f.read(200000).splitlines()
        except OSError:
            continue
        found = False
        for i, line in enumerate(lines):
            if q in line.lower():
                hits.append({"file": d["file"], "title": d["title"], "line": i, "text": line.strip()[:160], "mtime": d["mtime"]})
                found = True
                if sum(1 for h in hits if h["file"] == d["file"]) >= 3:
                    break
        if name_hit and not found:
            hits.append({"file": d["file"], "title": d["title"], "line": 0, "text": d["preview"], "mtime": d["mtime"]})
    hits.sort(key=lambda h: (-(q in h["title"].lower()), -h["mtime"]))
    out(hits[:60])


def cmd_new(a):
    os.makedirs(a.dir, exist_ok=True)
    title = (a.title or "").strip() or "Note " + dt.datetime.now().strftime("%d %b %Y, %H.%M")
    name = unique(a.dir, slug(title))
    with open(os.path.join(a.dir, name), "x", encoding="utf-8") as f:
        f.write("# %s\n\n" % title)
    print(name)


def cmd_rename(a):
    src = safe(a.dir, a.file)
    stem = slug(a.title)
    if os.path.basename(src) == stem + ".md":
        print(os.path.basename(src))
        return
    name = unique(a.dir, stem)
    os.rename(src, os.path.join(a.dir, name))
    # Keep the heading in step with the name, if the note starts with one
    path = os.path.join(a.dir, name)
    with open(path, encoding="utf-8", errors="replace") as f:
        text = f.read()
    m = re.match(r"^(\s*)#\s+.*", text)
    if m:
        text = m.group(1) + "# " + a.title.strip() + text[m.end():]
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
    print(name)


def cmd_trash(a):
    src = safe(a.dir, a.file)
    tdir = os.path.join(a.dir, ".trash")
    os.makedirs(tdir, exist_ok=True)
    stamp = dt.datetime.now().strftime("%Y%m%d-%H%M%S")
    shutil.move(src, os.path.join(tdir, stamp + " " + os.path.basename(src)))
    out({"ok": True})


def cmd_restore(a):
    tdir = os.path.join(a.dir, ".trash")
    if not a.name:
        try:
            names = sorted(os.listdir(tdir), reverse=True)
        except OSError:
            names = []
        out([{"name": n, "title": n[16:-3] if re.match(r"^\d{8}-\d{6} ", n) else n[:-3]} for n in names if n.endswith(".md")])
        return
    src = os.path.join(tdir, os.path.basename(a.name))
    orig = re.sub(r"^\d{8}-\d{6} ", "", os.path.basename(a.name))[:-3]
    name = unique(a.dir, orig)
    shutil.move(src, os.path.join(a.dir, name))
    print(name)


def cmd_watch(a):
    os.makedirs(a.dir, exist_ok=True)
    try:
        p = subprocess.Popen(["inotifywait", "-m", "-q", "-e", "close_write,moved_to,moved_from,create,delete",
                              "--format", "%f", a.dir], stdout=subprocess.PIPE, text=True)
    except OSError:
        sys.exit(1)
    for line in p.stdout:
        name = line.strip()
        if name.endswith(".md") and not name.startswith("."):
            print(name, flush=True)


def main():
    p = argparse.ArgumentParser(description="Lumen Notes")
    p.add_argument("--dir", default=os.environ.get("LUMEN_NOTES_DIR") or os.path.expanduser("~/Notes"))
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("ensure")
    sub.add_parser("list")
    s = sub.add_parser("search"); s.add_argument("query")
    s = sub.add_parser("new"); s.add_argument("title", nargs="?", default="")
    s = sub.add_parser("rename"); s.add_argument("file"); s.add_argument("title")
    s = sub.add_parser("trash"); s.add_argument("file")
    s = sub.add_parser("restore"); s.add_argument("name", nargs="?", default="")
    sub.add_parser("watch")
    a = p.parse_args()
    a.dir = os.path.abspath(os.path.expanduser(a.dir))
    globals()["cmd_" + a.cmd](a)


if __name__ == "__main__":
    main()
