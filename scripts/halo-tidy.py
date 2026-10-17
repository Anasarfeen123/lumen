#!/usr/bin/env python3
"""halo-tidy.py — tidy a folder (Downloads by default) into kinds, with undo.

  halo-tidy.py plan [dir]     JSON: {dir, moves: [{from, to}], counts: {kind: n}}
  halo-tidy.py apply <plan.json>   moves them (never overwrites: name (2).ext);
                              JSON: {done, skipped, log}  — the log is kept for undo
  halo-tidy.py undo           moves the last tidy back. JSON: {done, skipped}

Only files directly in the folder (not sub-folders), only ones untouched for
10 minutes (a download in progress stays put), never hidden files.
Kinds: Documents, Images, Screenshots, Videos, Music, Archives, Installers,
Code, Other. The log lives in ~/.local/state/lumen/tidy-last.json.
"""
import json
import os
import shutil
import sys
import time

KINDS = {
    "Documents": {"pdf", "doc", "docx", "odt", "rtf", "txt", "md", "ppt", "pptx", "odp", "xls", "xlsx", "ods", "csv", "epub", "tex"},
    "Images": {"png", "jpg", "jpeg", "gif", "webp", "svg", "heic", "bmp", "tiff", "avif"},
    "Videos": {"mp4", "mkv", "webm", "mov", "avi", "m4v"},
    "Music": {"mp3", "flac", "wav", "ogg", "m4a", "opus", "aac"},
    "Archives": {"zip", "tar", "gz", "xz", "bz2", "7z", "rar", "zst", "tgz"},
    "Installers": {"rpm", "deb", "appimage", "flatpakref", "run", "exe", "msi", "iso", "img"},
    "Code": {"py", "c", "cpp", "h", "java", "js", "ts", "html", "css", "json", "ipynb", "sh", "rs", "go", "kt", "sql"},
}
PARTIAL = (".part", ".crdownload", ".download", ".opdownload", ".tmp")
LOG = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "lumen", "tidy-last.json")


def kind_of(name):
    low = name.lower()
    if low.startswith(("screenshot", "screen shot", "lens_")) and low.endswith((".png", ".jpg")):
        return "Screenshots"
    ext = low.rsplit(".", 1)[-1] if "." in low else ""
    for k, exts in KINDS.items():
        if ext in exts:
            return k
    return "Other"


def plan(d):
    d = os.path.expanduser(d or "~/Downloads")
    moves, counts, now = [], {}, time.time()
    for e in sorted(os.scandir(d), key=lambda e: e.name.lower()):
        if not e.is_file(follow_symlinks=False) or e.name.startswith(".") or e.name.lower().endswith(PARTIAL):
            continue
        if now - e.stat().st_mtime < 600:
            continue
        k = kind_of(e.name)
        moves.append({"from": e.path, "to": os.path.join(d, k, e.name)})
        counts[k] = counts.get(k, 0) + 1
    return {"dir": d, "moves": moves, "counts": counts}


def free(path):
    if not os.path.exists(path):
        return path
    base, ext = os.path.splitext(path)
    i = 2
    while os.path.exists("%s (%d)%s" % (base, i, ext)):
        i += 1
    return "%s (%d)%s" % (base, i, ext)


def apply(planfile):
    with open(planfile) as f:
        p = json.load(f)
    log, skipped = [], 0
    for m in p.get("moves", []):
        src = m["from"]
        if not os.path.isfile(src):
            skipped += 1
            continue
        dst = free(m["to"])
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        shutil.move(src, dst)
        log.append({"from": src, "to": dst})
    os.makedirs(os.path.dirname(LOG), exist_ok=True)
    with open(LOG, "w") as f:
        json.dump({"at": time.time(), "log": log}, f)
    return {"done": len(log), "skipped": skipped}


def undo():
    try:
        with open(LOG) as f:
            log = json.load(f).get("log", [])
    except (OSError, ValueError):
        return {"done": 0, "skipped": 0, "error": "Nothing to undo."}
    done = skipped = 0
    for m in reversed(log):
        if os.path.isfile(m["to"]) and not os.path.exists(m["from"]):
            shutil.move(m["to"], m["from"])
            done += 1
            try:
                os.rmdir(os.path.dirname(m["to"]))          # only if now empty
            except OSError:
                pass
        else:
            skipped += 1
    os.remove(LOG)
    return {"done": done, "skipped": skipped}


def main():
    a = sys.argv[1:]
    if a and a[0] == "plan":
        print(json.dumps(plan(a[1] if len(a) > 1 else "")))
    elif len(a) == 2 and a[0] == "apply":
        print(json.dumps(apply(a[1])))
    elif a and a[0] == "undo":
        print(json.dumps(undo()))
    else:
        print(__doc__)
        sys.exit(2)


if __name__ == "__main__":
    main()
