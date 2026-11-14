#!/usr/bin/env python3
"""ai-limits.py — when your coding assistants' usage limits reset.

  ai-limits.py        JSON: {claude: {...} | null, codex: {...} | null}
    claude  from ccusage (installed once at ~/.local/share/lumen/ccusage; reads
            ~/.claude/projects, nothing leaves this computer): the active 5-hour
            block — {start, reset, cost, tokens} in ms since the epoch
    codex   from Codex's own session logs (~/.codex/sessions), the limits Codex
            last reported: {five: {used, reset}, week: {used, reset}, seen}
Only local files are read; ccusage runs with --offline.
"""
import glob, json, os, subprocess, time
from datetime import datetime

HOME = os.path.expanduser("~")
CCUSAGE = os.path.join(os.environ.get("XDG_DATA_HOME") or HOME + "/.local/share", "lumen/ccusage/node_modules/.bin/ccusage")


def ms(iso):
    return int(datetime.fromisoformat(iso.replace("Z", "+00:00")).timestamp() * 1000)


def claude():
    if not os.access(CCUSAGE, os.X_OK) or not os.path.isdir(HOME + "/.claude/projects"):
        return None
    try:
        out = subprocess.run([CCUSAGE, "blocks", "--active", "--json", "--offline"],
                             capture_output=True, text=True, timeout=90).stdout
        blocks = json.loads(out).get("blocks", [])
    except (OSError, ValueError, subprocess.TimeoutExpired):
        return None
    b = next((b for b in blocks if b.get("isActive") and not b.get("isGap")), None)
    if not b:
        return {"active": False}
    return {"active": True, "start": ms(b["startTime"]), "reset": ms(b["endTime"]),
            "cost": round(b.get("costUSD", 0), 2), "tokens": b.get("totalTokens", 0)}


def codex():
    files = glob.glob(HOME + "/.codex/sessions/*/*/*/*.jsonl")
    if not files:
        return None
    # the newest session that reported limits (the last report in it wins)
    for f in sorted(files, key=os.path.getmtime, reverse=True)[:8]:
        last = None
        try:
            with open(f, errors="replace") as fh:
                for line in fh:
                    if '"rate_limits"' in line:
                        last = line
        except OSError:
            continue
        if not last:
            continue
        try:
            o = json.loads(last)
        except ValueError:
            continue
        # the rate_limits object sits somewhere inside the event
        stack, rl = [o], None
        while stack and rl is None:
            x = stack.pop()
            if isinstance(x, dict):
                if isinstance(x.get("rate_limits"), dict):
                    rl = x["rate_limits"]
                stack.extend(x.values())
            elif isinstance(x, list):
                stack.extend(x)
        if not rl:
            continue
        def win(w):
            if not isinstance(w, dict) or not w.get("resets_at"):
                return None
            return {"used": w.get("used_percent", 0), "reset": int(w["resets_at"]) * 1000, "minutes": w.get("window_minutes")}
        return {"five": win(rl.get("primary")), "week": win(rl.get("secondary")), "seen": int(os.path.getmtime(f) * 1000)}
    return None


if __name__ == "__main__":
    print(json.dumps({"claude": claude(), "codex": codex(), "at": int(time.time() * 1000)}))
