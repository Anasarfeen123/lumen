#!/usr/bin/env python3
"""lumen-config.py — every Lumen setting in one readable file, ~/.local/state/lumen/lumen.toml.

  [look]   theme, accent, glass, corners, gaps… (state.json; a change rebuilds the theme)
  [shell]  everything Settings stores for the shell (shell.json; applied at once)

Edit it and save: the change applies (`lumen config` opens it). Change something
in Settings and the file follows. A value must keep its type and the key must
already exist — anything else is refused and reported, never written. Lists and
on/off, numbers and text are here; nested data (Halo's memory, routines…) stays
in Settings.

  lumen-config.py write     regenerate lumen.toml from the settings
  lumen-config.py apply     put lumen.toml's values into the settings
  lumen-config.py watch     both, whenever either side changes (the shell runs this)
  lumen-config.py path
"""
import json, os, re, subprocess, sys, tomllib

STATE = os.path.join(os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"), "lumen")
ROOT = os.environ.get("LUMEN_ROOT") or os.path.expanduser("~/.config/lumen")
TOML = os.path.join(STATE, "lumen.toml")
FILES = {"look": os.path.join(STATE, "state.json"), "shell": os.path.join(STATE, "shell.json")}
HEAD = """# Lumen's settings — edit and save, they apply by themselves.
# [look] rebuilds the theme; [shell] applies at once. Keys and types are fixed:
# a wrong one is refused (see `lumen doctor` or the notification). Settings and
# this file stay in step; comments you add here aren't kept.
"""


def load(p):
    try:
        with open(p) as f:
            return json.load(f)
    except (OSError, ValueError):
        return {}


def simple(v):
    if isinstance(v, (bool, int, float, str)):
        return True
    return isinstance(v, list) and all(isinstance(x, (bool, int, float, str)) for x in v) and len({type(x) for x in v}) <= 1


def key(k):
    return k if re.fullmatch(r"[A-Za-z0-9_-]+", k) else json.dumps(k)


def val(v):
    if isinstance(v, bool):
        return "true" if v else "false"
    if isinstance(v, list):
        return "[" + ", ".join(val(x) for x in v) + "]"
    if isinstance(v, float) and v.is_integer():
        return repr(v)
    return json.dumps(v, ensure_ascii=False)


def render():
    out = [HEAD]
    for sec, path in FILES.items():
        d = load(path)
        keep = sorted(k for k, v in d.items() if simple(v))
        rest = sorted(k for k, v in d.items() if not simple(v))
        out.append("[%s]" % sec)
        out += ["%s = %s" % (key(k), val(d[k])) for k in keep]
        if rest:
            out.append("# kept in Settings: " + ", ".join(rest))
        out.append("")
    return "\n".join(out)


def atomic(path, text):
    with open(path + ".tmp", "w") as f:
        f.write(text)
    os.replace(path + ".tmp", path)


def write():
    text = render()
    try:
        with open(TOML, "rb") as f:
            same = tomllib.load(f) == tomllib.loads(text)
    except (OSError, tomllib.TOMLDecodeError):
        same = False
    if not same:                      # unchanged values: keep the file as the user left it
        atomic(TOML, text)


def kind(v):
    return "number" if isinstance(v, (int, float)) and not isinstance(v, bool) else type(v).__name__


def apply():
    try:
        with open(TOML, "rb") as f:
            t = tomllib.load(f)
    except OSError:
        return {"ok": True, "changed": []}
    except tomllib.TOMLDecodeError as e:
        return {"error": "lumen.toml isn't valid TOML: %s" % e}
    changed, refused, look = [], [], False
    for sec, path in FILES.items():
        d = load(path)
        new = dict(d)
        for k, v in (t.get(sec) or {}).items():
            if k not in d:
                refused.append("%s.%s: no such setting" % (sec, k)); continue
            if not simple(d[k]):
                continue
            if kind(v) != kind(d[k]) or (isinstance(v, list) and v and d[k] and kind(v[0]) != kind(d[k][0])):
                refused.append("%s.%s: should be %s" % (sec, k, kind(d[k]))); continue
            if v != d[k]:
                new[k] = v; changed.append("%s.%s" % (sec, k)); look = look or sec == "look"
        if new != d:
            atomic(path, json.dumps(new, indent=4 if sec == "shell" else 2) + "\n")
    if look:
        subprocess.run([os.path.join(ROOT, "bin", "lumen"), "theme"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return {"ok": not refused, "changed": changed, "refused": refused}


def notify(r):
    if r.get("refused") or r.get("error"):
        msg = r.get("error") or "Not applied: " + "; ".join(r["refused"])
        subprocess.run(["notify-send", "-a", "Lumen", "lumen.toml", msg], stderr=subprocess.DEVNULL)


def watch():
    write()
    names = {os.path.basename(p) for p in FILES.values()} | {"lumen.toml"}
    w = subprocess.Popen(["inotifywait", "-m", "-q", "-e", "close_write,moved_to", "--format", "%f", STATE],
                         stdout=subprocess.PIPE, text=True)
    for line in w.stdout:
        f = line.strip()
        if f not in names:
            continue
        if f == "lumen.toml":
            r = apply()
            notify(r)
            print(json.dumps(r), flush=True)
        else:
            write()


def main():
    a = sys.argv[1:]
    if a[:1] == ["write"]:
        write()
    elif a[:1] == ["apply"]:
        r = apply(); print(json.dumps(r)); sys.exit(0 if r.get("ok") else 1)
    elif a[:1] == ["watch"]:
        watch()
    elif a[:1] == ["path"]:
        print(TOML)
    else:
        print(__doc__); sys.exit(2)


if __name__ == "__main__":
    main()
