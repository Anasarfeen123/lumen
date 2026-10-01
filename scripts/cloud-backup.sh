#!/bin/sh
# cloud-backup.sh — Lumen's cloud backups, through rclone (Google Drive,
# OneDrive, Dropbox, S3, WebDAV, Nextcloud… — whatever you set up with
# `rclone config`). Nothing here talks to a cloud by itself: rclone does,
# with the account you authorised in your browser.
#
#   cloud-backup.sh status            JSON: rclone installed?, your remotes (encrypted ones marked),
#                                     the chosen remote/folder, last backup
#   cloud-backup.sh set <remote:> [folder]   where backups go (default folder "Lumen Backups/<host>")
#   cloud-backup.sh unset             stop cloud backups (nothing in the cloud is touched)
#   cloud-backup.sh run               copy what changed; progress as JSON lines {"p":0-100,"st":"…"}
#   cloud-backup.sh restore <folder>  copy that folder back into ~/Restored/cloud-<date>/ (never over your files)
#   cloud-backup.sh setup             open rclone's own setup in a terminal (you sign in in your browser)
#
# How it keeps your data safe:
#   · copy, never sync: files you delete locally stay in the cloud
#   · a changed file's previous version moves to <folder>/versions/<date>/ (rclone --backup-dir)
#   · choose a "crypt" remote and rclone encrypts names and contents before anything leaves
# The folders and excludes are the same as the drive backups (~/.local/state/lumen/backup.json).
set -u
CONF=${XDG_STATE_HOME:-$HOME/.local/state}/lumen/backup.json
LUMEN_ROOT=${LUMEN_ROOT:-$HOME/.config/lumen}
LOG=${XDG_RUNTIME_DIR:-/tmp}/lumen-cloud-backup.log
HOST=$(hostname -s 2>/dev/null || hostname)

have() { command -v rclone >/dev/null 2>&1; }
conf() { jq -r "$1" "$CONF" 2>/dev/null; }
edit() {   # edit <jq args…> <filter>
    tmp=$(mktemp "$CONF.XXXXXX") || exit 1
    [ -s "$CONF" ] || echo '{}' > "$CONF"
    if jq "$@" "$CONF" > "$tmp"; then mv "$tmp" "$CONF"; else rm -f "$tmp"; exit 1; fi
}
island() { "$LUMEN_ROOT/bin/lumen-shell-ipc" island "$@" >/dev/null 2>&1 || true; }

case ${1:-} in
status)
    installed=false; remotes='[]'
    if have; then
        installed=true
        remotes=$(rclone listremotes --long 2>/dev/null | awk '{ n = $1; sub(/:$/, "", n); printf "%s{\"name\":\"%s\",\"type\":\"%s\"}", (NR > 1 ? "," : ""), n, $2 }' | sed 's/^/[/; s/$/]/')
        [ -n "$remotes" ] || remotes='[]'
    fi
    jq -cn --argjson i "$installed" --argjson r "$remotes" --argjson c "$(jq -c '.cloud // {}' "$CONF" 2>/dev/null || echo '{}')" \
        '{installed: $i, remotes: ($r | map(. + {encrypted: (.type == "crypt")})), cloud: $c}' ;;
set)
    remote=${2:-}; folder=${3:-"Lumen Backups/$HOST"}
    printf '%s' "$remote" | grep -Eqx '[A-Za-z0-9_. -]+:' || { echo "Not a remote name (like gdrive:)" >&2; exit 2; }
    case $folder in /*|*..*) echo "The folder must be relative, without '..'" >&2; exit 2 ;; esac
    have && ! rclone listremotes 2>/dev/null | grep -qxF "$remote" && { echo "No remote called $remote — set one up first" >&2; exit 2; }
    edit --arg r "$remote" --arg f "$folder" '.cloud = ((.cloud // {}) + {remote: $r, folder: $f})'
    echo ok ;;
unset)
    edit 'del(.cloud.remote)'; echo ok ;;
setup)
    have || { echo "rclone isn't installed (Fedora: sudo dnf install rclone)" >&2; exit 1; }
    exec kitty --title "Set up a cloud for Lumen backups" sh -c 'echo "rclone setup — choose n (new remote), give it a short name (e.g. gdrive), pick your cloud, and sign in in the browser when asked."; echo "Tip: afterwards add a \"crypt\" remote on top of it to encrypt your backups."; echo; rclone config; echo; echo "Done — go back to Settings → Backup & recovery."; read -r _' ;;
run)
    have || { jq -cn '{e:"rclone isn'\''t installed"}'; exit 1; }
    remote=$(conf '.cloud.remote // ""'); folder=$(conf '.cloud.folder // ""')
    [ -n "$remote" ] || { jq -cn '{e:"No cloud chosen"}'; exit 1; }
    stamp=$(date +%Y-%m-%d_%H%M)
    : > "$LOG"
    island progress cloud "Backing up to $remote" -1 "Starting…"
    excl=$(mktemp); jq -r '.exclude[]? // empty' "$CONF" > "$excl"
    total=$(jq -r '.folders | length' "$CONF"); n=0; fail=0
    for f in $(jq -r '.folders[]? | @base64' "$CONF"); do
        src=$(printf '%s' "$f" | base64 -d)
        [ -d "$src" ] || continue
        n=$((n + 1)); rel=${src#"$HOME"/}
        jq -cn --arg s "$rel" --argjson p "$(( (n - 1) * 100 / (total > 0 ? total : 1) ))" '{p:$p, st:$s}'
        island progress cloud "Backing up to $remote" "$(( (n - 1) * 100 / (total > 0 ? total : 1) ))" "$rel"
        # copy (never sync): nothing is ever deleted in the cloud; replaced files keep their old version
        rclone copy "$src" "$remote$folder/current/$rel" --exclude-from "$excl" \
            --backup-dir "$remote$folder/versions/$stamp/$rel" --transfers 4 --checkers 8 \
            --log-file "$LOG" --log-level NOTICE || fail=$((fail + 1))
    done
    rm -f "$excl"
    ok=true; [ "$fail" -eq 0 ] || ok=false
    edit --arg t "$(date +%s)" --argjson ok "$ok" '.cloud.last = {time: ($t | tonumber), ok: $ok}'
    if $ok; then island progressDone cloud "Backed up to $remote" true "$n folders"; jq -cn '{p:100, st:"done"}'
    else island progressDone cloud "Cloud backup had problems" false "$fail of $n folders · see Settings"; jq -cn --argjson f "$fail" '{e:("\($f) folder(s) failed — details in the log")}'; exit 1; fi ;;
restore)
    have || exit 1
    rel=${2:?usage: cloud-backup.sh restore <folder relative to home>}
    case $rel in /*|*..*) echo "Relative folder only" >&2; exit 2 ;; esac
    remote=$(conf '.cloud.remote // ""'); folder=$(conf '.cloud.folder // ""')
    [ -n "$remote" ] || exit 1
    to="$HOME/Restored/cloud-$(date +%Y-%m-%d_%H%M)/$rel"
    mkdir -p "$to"
    rclone copy "$remote$folder/current/$rel" "$to" --log-file "$LOG" --log-level NOTICE && echo "$to" ;;
*)
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
