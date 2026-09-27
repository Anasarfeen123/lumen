#!/bin/sh
# lumen-self-update.sh — Lumen updates itself from its own git remote.
#   lumen-self-update.sh check          fetch origin/<branch> (never touches your files) and report:
#                                       {branch, current, date, remote, behind, ahead, dirty, dirtyFiles,
#                                        diverged, changes:[{sha, date, subject, body}], checkedAt}
#   lumen-self-update.sh apply          fast-forward to origin/<branch>, rebuild the theme. Refuses when
#                                       you have uncommitted changes or your branch has diverged.
#   lumen-self-update.sh stash-apply    stash your changes first (git stash push -u), then apply;
#                                       get them back afterwards with: git -C <repo> stash pop
#   lumen-self-update.sh set daily on|off   the shell's once-a-day check
#   lumen-self-update.sh settings       {daily, announced}
# Every mode also writes its result to $XDG_RUNTIME_DIR/lumen-self-update.json
# (Settings → Updates watches it) and logs to $XDG_RUNTIME_DIR/lumen-update.log.
# The repository is $LUMEN_ROOT (default ~/.config/lumen). Network: only
# `git fetch` from the repository's own origin. Never reset --hard, never force.
set -u
ROOT=${LUMEN_ROOT:-$HOME/.config/lumen}
RUN=${XDG_RUNTIME_DIR:-/tmp}
STATE=$RUN/lumen-self-update.json
LOG=$RUN/lumen-update.log
PREFS=${XDG_STATE_HOME:-$HOME/.local/state}/lumen/self-update.json

log() { printf '%s %s\n' "$(date '+%F %T')" "$*" >> "$LOG"; }
g() { git -C "$ROOT" "$@"; }
# publish <json>: print it and save it for the Settings page
publish() { printf '%s\n' "$1"; printf '%s\n' "$1" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"; }
fail() {   # fail <state> <message> [extra-json-object]
    x=${3:-}; [ -n "$x" ] || x='{}'
    publish "$(jq -cn --arg s "$1" --arg m "$2" --argjson x "$x" --argjson t "$(date +%s)" \
        '$x + {state: $s, error: $m, checkedAt: ($t * 1000)}')"
    log "$1: $2"
    exit 1
}

branch=""; remote=""
repo() {
    g rev-parse --is-inside-work-tree >/dev/null 2>&1 || fail error "$ROOT isn't a git checkout, so Lumen can't update itself here."
    branch=$(g symbolic-ref --quiet --short HEAD 2>/dev/null) || fail error "Lumen isn't on a branch (detached HEAD)."
    remote=$(g remote get-url origin 2>/dev/null) || fail error "This checkout has no 'origin' remote."
}

dirty_files() { g status --porcelain --untracked-files=normal 2>/dev/null | cut -c4- | head -n 20; }

# report <state>: the full picture as JSON
report() {
    behind=$(g rev-list --count "HEAD..origin/$branch" 2>/dev/null || echo 0)
    ahead=$(g rev-list --count "origin/$branch..HEAD" 2>/dev/null || echo 0)
    files=$(dirty_files | jq -R . | jq -sc .)
    changes=$(g log --format='%h%x1f%cI%x1f%s%x1f%b%x1e' -n 30 "HEAD..origin/$branch" 2>/dev/null |
        jq -Rsc 'split("\u001e") | map(select(test("\\S")) | ltrimstr("\n") | split("\u001f")
                 | {sha: .[0], date: .[1], subject: .[2],
                    body: ((.[3] // "") | split("\n") | map(select(test("\\S") and (test("^(Co-Authored-By|Claude-Session|Signed-off-by):") | not))) | .[0:2] | join(" "))})')
    jq -cn --arg s "$1" --arg b "$branch" --arg r "$remote" \
        --arg cur "$(g rev-parse --short HEAD)" --arg date "$(g log -1 --format=%cI HEAD)" \
        --arg rsha "$(g rev-parse --short "origin/$branch" 2>/dev/null)" \
        --argjson behind "${behind:-0}" --argjson ahead "${ahead:-0}" --argjson files "${files:-[]}" \
        --argjson changes "${changes:-[]}" --argjson t "$(date +%s)" '
        {state: $s, branch: $b, remote: $r, remoteSha: $rsha, current: $cur, date: $date, behind: $behind, ahead: $ahead,
         dirty: ($files | length > 0), dirtyFiles: $files, diverged: ($ahead > 0 and $behind > 0),
         changes: $changes, checkedAt: ($t * 1000)}'
}

fetch() {
    log "fetch origin $branch ($remote)"
    timeout 30 git -C "$ROOT" fetch --quiet origin "$branch" >> "$LOG" 2>&1 \
        || fail offline "Couldn't reach $remote — check your connection and try again."
}

prefs() { [ -s "$PREFS" ] && jq -e type "$PREFS" >/dev/null 2>&1 && cat "$PREFS" || echo '{"daily":true,"announced":""}'; }

apply() {
    fetch
    r=$(report checked)
    [ "$(printf '%s' "$r" | jq -r .dirty)" = true ] && fail dirty "You have changes that aren't committed. Commit or stash them first — or use Stash & update." "$r"
    [ "$(printf '%s' "$r" | jq -r .diverged)" = true ] && fail diverged "Your copy and GitHub have both moved on. Lumen won't merge or overwrite — update it by hand with git." "$r"
    [ "$(printf '%s' "$r" | jq -r .behind)" = 0 ] && { publish "$(report current)"; exit 0; }
    before=$(g rev-parse --short HEAD)
    publish "$(printf '%s' "$r" | jq -c '.state = "updating"')"
    log "pull --ff-only ($before → origin/$branch)"
    g pull --ff-only --quiet origin "$branch" >> "$LOG" 2>&1 || fail failed "The update couldn't be applied (see $LOG). Nothing was changed." "$r"
    log "rebuild theme"
    python3 "$ROOT/theme/build.py" >> "$LOG" 2>&1 || log "theme rebuild failed (Lumen still works; lumen rebuild retries)"
    after=$(g rev-parse --short HEAD)
    log "updated $before → $after"
    publish "$(report updated | jq -c --arg b "$before" '.from = $b')"
}

case ${1:-} in
check)
    repo
    publish "$(report checking)" >/dev/null
    fetch
    publish "$(report checked)" ;;
apply)
    repo; apply ;;
stash-apply)
    repo
    if [ -n "$(dirty_files)" ]; then
        msg="lumen-update $(date '+%F %H:%M')"
        log "stash push -u -m \"$msg\""
        g stash push --include-untracked --quiet -m "$msg" >> "$LOG" 2>&1 || fail failed "Couldn't stash your changes (see $LOG). Nothing was changed."
    fi
    apply ;;
set)
    [ "${2:-}" = daily ] || { echo "usage: lumen-self-update.sh set daily on|off" >&2; exit 2; }
    case ${3:-} in on) v=true ;; off) v=false ;; *) echo "usage: lumen-self-update.sh set daily on|off" >&2; exit 2 ;; esac
    mkdir -p "$(dirname "$PREFS")"
    prefs | jq -c --argjson v "$v" '.daily = $v' > "$PREFS.tmp" && mv "$PREFS.tmp" "$PREFS" ;;
announced)   # (the shell) remember which remote commit was announced
    mkdir -p "$(dirname "$PREFS")"
    prefs | jq -c --arg s "${2:-}" '.announced = $s' > "$PREFS.tmp" && mv "$PREFS.tmp" "$PREFS" ;;
settings)
    prefs ;;
*)
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
