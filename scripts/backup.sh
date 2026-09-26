#!/bin/sh
# backup.sh — Lumen's file backups: rsync snapshots of your folders onto a
# drive or folder you choose. Each run is a full, browsable copy; unchanged
# files are hard links to the previous snapshot, so a second run takes almost
# no space. Nothing here ever deletes or overwrites your own files.
#
#   backup.sh status                 JSON: config, destination state, snapshots, schedule
#   backup.sh init                   write a default config if there is none
#   backup.sh set-dest <folder>      where snapshots go (a drive's mount point, or any folder)
#   backup.sh add-folder <folder>    back this folder up too
#   backup.sh remove-folder <folder> stop backing it up (existing snapshots stay)
#   backup.sh set-keep <n>           keep the newest n snapshots (0 = keep all); older ones go to the trash
#   backup.sh run                    back up now; progress as JSON lines {"p":0-100,"st":"…"} and in the island
#   backup.sh due [mountpoint]       exit 0 if a backup is due (never, or > 7 days) [and it goes to that drive]
#   backup.sh run-on <device>        mount that drive if needed and, if it's the backup drive, back up
#   backup.sh open [snapshot]        show the snapshots (or one) in the file manager
#   backup.sh restore <snapshot> <folder>   copy a folder from a snapshot into ~/Restored/<snapshot>/ (never over your files)
#   backup.sh timer on|off|status    daily backup with a systemd --user timer
#
# Config: ~/.local/state/lumen/backup.json
#   { dest, destUuid, folders: [...], exclude: [...], keep, last: { time, ok, snapshot, size } }
# Snapshots: <dest>/Lumen Backups/<hostname>/<YYYY-MM-DD_HHMM>/<path relative to ~>/…
set -u
LUMEN_ROOT=${LUMEN_ROOT:-$HOME/.config/lumen}
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/lumen
CONF=$STATE_DIR/backup.json
HOST=$(hostname 2>/dev/null || cat /etc/hostname 2>/dev/null || echo this-computer)
IPC=$LUMEN_ROOT/bin/lumen-shell-ipc

die() { jq -cn --arg e "$1" '{e:$e}'; exit 1; }
conf() { jq -r "$1" "$CONF" 2>/dev/null; }
save() {   # save <jq filter> [jq args…] — atomic
    f=$1; shift
    tmp=$(mktemp "$CONF.XXXXXX") || exit 1
    if jq "$@" "$f" "$CONF" > "$tmp"; then mv "$tmp" "$CONF"; else rm -f "$tmp"; exit 1; fi
}
island() { [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] && "$IPC" island "$@" >/dev/null 2>&1; return 0; }
root_of() { printf '%s/Lumen Backups/%s' "$1" "$HOST"; }
snapshots() { d=$(root_of "$1"); [ -d "$d" ] && find "$d" -mindepth 1 -maxdepth 1 -type d -name '20[0-9][0-9]-*' -printf '%f\n' | sort; }
# File systems without hard links / symlinks / Unix permissions (USB sticks often are)
plainfs() { case $(stat -f -c %T "$1" 2>/dev/null) in msdos|vfat|exfat|fuseblk|fat) return 0 ;; esac; return 1; }

init() {
    [ -s "$CONF" ] && return 0
    mkdir -p "$STATE_DIR"
    folders=$(for d in Documents Pictures Projects Desktop Music Videos; do [ -d "$HOME/$d" ] && printf '%s\n' "$HOME/$d"; done | jq -R . | jq -sc .)
    jq -n --argjson f "$folders" '{dest:"", folders:$f,
        exclude:["node_modules",".cache","target","build","*.iso",".venv","__pycache__",".Trash-*"], keep:30, last:null}' > "$CONF"
}

case ${1:-} in
init) init; echo ok ;;
status)
    init
    dest=$(conf '.dest // ""')
    ok=false; why="No destination chosen yet"; free=0; fs=""
    if [ -n "$dest" ]; then
        if [ ! -d "$dest" ]; then why="Not connected — plug in the drive"
        elif [ ! -w "$dest" ]; then why="Can't write there"
        else ok=true; why=""; free=$(df -B1 --output=avail "$dest" | tail -n 1 | tr -d ' '); fs=$(stat -f -c %T "$dest"); fi
    fi
    snaps=$( [ "$ok" = true ] && snapshots "$dest" | jq -R . | jq -sc . || echo '[]')
    timer=false; systemctl --user is-enabled -q lumen-backup.timer 2>/dev/null && timer=true
    jq -c --argjson ok "$ok" --arg why "$why" --argjson free "${free:-0}" --arg fs "$fs" --argjson s "$snaps" \
          --argjson timer "$timer" --arg root "$( [ -n "$dest" ] && root_of "$dest")" \
          '. + {destOk:$ok, destProblem:$why, free:$free, fs:$fs, snapshots:$s, root:$root, timer:$timer}' "$CONF" ;;
set-dest)
    init; d=${2:?}; d=$(realpath -m -- "$d")
    [ -d "$d" ] || die "That folder doesn't exist."
    for f in $(conf '.folders[]'); do case $d/ in "$f"/*) die "The destination can't be inside a folder you're backing up ($f)." ;; esac; done
    # Remember the drive's file-system id, so the island recognises it when plugged in
    uuid=$(findmnt -no UUID --target "$d" 2>/dev/null | head -n 1)
    save '.dest = $d | .destUuid = $u' --arg d "$d" --arg u "$uuid"; echo ok ;;
run-on)
    # The island's "Back up" on a drive card: mount it if needed, check it's the
    # backup drive, then run
    init; dev=${2:?}
    case $dev in /dev/*) ;; *) die "Not a device." ;; esac
    mp=$(findmnt -nro TARGET --source "$dev" | head -n 1)
    if [ -z "$mp" ]; then udisksctl mount -b "$dev" --no-user-interaction >/dev/null 2>&1 || die "Couldn't mount the drive."
        mp=$(findmnt -nro TARGET --source "$dev" | head -n 1); fi
    case $(conf '.dest')/ in "$mp"/*) ;; *) die "This isn't your backup drive." ;; esac
    exec "$0" run ;;
add-folder)
    init; f=$(realpath -- "${2:?}" 2>/dev/null) || die "That folder doesn't exist."
    case $f/ in "$HOME"/*) ;; *) die "Only folders inside your home can be backed up." ;; esac
    [ "$f" = "$HOME" ] && die "Pick specific folders rather than your whole home."
    save '.folders = ((.folders + [$f]) | unique)' --arg f "$f"; echo ok ;;
remove-folder)
    init; save '.folders -= [$f]' --arg f "${2:?}"; echo ok ;;
set-keep)
    init; case ${2:-} in ''|*[!0-9]*) die "keep must be a number" ;; esac
    save '.keep = ($k | tonumber)' --arg k "$2"; echo ok ;;
due)
    init
    dest=$(conf '.dest // ""'); [ -n "$dest" ] || exit 1
    if [ -n "${2:-}" ]; then case $dest/ in "$2"/*) ;; *) exit 1 ;; esac; fi
    last=$(conf '.last.time // 0')
    [ $(( $(date +%s) - last )) -gt $((7 * 86400)) ] ;;
open)
    init; dest=$(conf '.dest // ""'); r=$(root_of "$dest")
    [ -d "$r" ] || die "No backups there yet."
    if [ -n "${2:-}" ]; then [ -d "$r/$2" ] || die "No such snapshot."; exec xdg-open "$r/$2"; fi
    exec xdg-open "$r" ;;
restore)
    init; snap=${2:?}; rel=${3:?}
    case $snap$rel in *..*) die "Invalid path." ;; esac
    rel=${rel#"$HOME"/}; rel=${rel#/}
    src="$(root_of "$(conf '.dest')")/$snap/$rel"
    [ -e "$src" ] || die "That folder isn't in snapshot $snap."
    out="$HOME/Restored/$snap/$rel"; n=1
    while [ -e "$out" ]; do out="$HOME/Restored/$snap/$rel ($n)"; n=$((n + 1)); done
    mkdir -p "$out"
    if [ -d "$src" ]; then rsync -a -- "$src/" "$out/" || die "Copy failed."
    else rmdir "$out"; rsync -a -- "$src" "$out" || die "Copy failed."; fi
    island event settings_backup_restore "Restored" "$rel → ~/Restored/$snap"
    jq -cn --arg o "$out" '{ok:true, path:$o}' ;;
timer)
    unit_dir=$HOME/.config/systemd/user
    case ${2:-status} in
    on)
        mkdir -p "$unit_dir"
        ln -sfn "$LUMEN_ROOT/systemd/lumen-backup.service" "$unit_dir/lumen-backup.service"
        ln -sfn "$LUMEN_ROOT/systemd/lumen-backup.timer" "$unit_dir/lumen-backup.timer"
        systemctl --user daemon-reload && systemctl --user enable --now lumen-backup.timer >/dev/null 2>&1 && echo on ;;
    off)
        systemctl --user disable --now lumen-backup.timer >/dev/null 2>&1
        rm -f "$unit_dir/lumen-backup.timer" "$unit_dir/lumen-backup.service"   # our own symlinks only
        systemctl --user daemon-reload; echo off ;;
    *) systemctl --user is-enabled -q lumen-backup.timer 2>/dev/null && echo on || echo off ;;
    esac ;;
run)
    init
    exec 9>"$STATE_DIR/backup.lock"
    flock -n 9 || die "A backup is already running."
    dest=$(conf '.dest // ""')
    [ -n "$dest" ] || die "Choose where backups go first (Settings → Backup & recovery)."
    [ -d "$dest" ] || { [ "${LUMEN_BACKUP_QUIET:-}" = 1 ] && exit 0; die "The backup drive isn't connected."; }
    [ -w "$dest" ] || die "Can't write to $dest."
    folders=$(conf '.folders[]' | while IFS= read -r f; do [ -d "$f" ] && printf '%s\n' "$f"; done)
    [ -n "$folders" ] || die "No folders to back up."
    # Never back up into a source
    rdest=$(realpath -- "$dest")
    echo "$folders" | while IFS= read -r f; do case $rdest/ in "$f"/*) exit 1 ;; esac; done || die "The destination is inside a folder you're backing up."

    root=$(root_of "$dest"); mkdir -p "$root" || die "Can't create $root."
    prev=$(snapshots "$dest" | tail -n 1)
    stamp=$(date +%Y-%m-%d_%H%M); new="$root/$stamp"
    [ -e "$new" ] && die "A snapshot from this minute already exists — try again in a minute."
    part="$root/.in-progress-$stamp"

    # Space: a first backup needs roughly the size of the folders
    avail=$(df -B1 --output=avail "$dest" | tail -n 1 | tr -d ' ')
    if [ -z "$prev" ] || plainfs "$dest"; then
        printf '{"p":-1,"st":"Measuring"}\n'
        need=$(printf '%s\n' "$folders" | tr '\n' '\0' | du -sbc --files0-from=- 2>/dev/null | tail -n 1 | cut -f1)
        [ "${need:-0}" -lt "${avail:-0}" ] || die "Not enough space: needs about $((need / 1000000000)) GB, $((avail / 1000000000)) GB free."
    elif [ "${avail:-0}" -lt 1000000000 ]; then
        die "Less than 1 GB free on the backup drive."
    fi

    # rsync's arguments: flags, excludes, then sources as ~/./rel so paths stay
    # relative to home (folder names may contain spaces: split on newlines only)
    set -f
    if plainfs "$dest"; then set -- -rltD --modify-window=2
    else set -- -aHAX; [ -n "$prev" ] && set -- "$@" --link-dest="$root/$prev"; fi
    oldifs=$IFS; IFS='
'
    for x in $(conf '.exclude[]'); do set -- "$@" --exclude="$x"; done
    for f in $folders; do set -- "$@" "$HOME/./${f#"$HOME"/}"; done
    IFS=$oldifs; set +f

    island progress backup backup "Backing up" 0 "to $(basename "$dest")"
    start=$(date +%s); last=-1
    { rsync -R --info=progress2 --no-inc-recursive --partial "$@" "$part/"; echo "rc=$?"; } 2>"$STATE_DIR/backup.err" |
        tr '\r' '\n' | while IFS= read -r line; do
            case $line in
            rc=*) echo "${line#rc=}" > "$STATE_DIR/backup.rc" ;;
            *%*) p=$(printf '%s' "$line" | grep -o '[0-9]*%' | head -n 1 | tr -d '%')
                 if [ -n "$p" ] && [ "$p" != "$last" ]; then last=$p
                     printf '{"p":%s,"st":"Copying"}\n' "$p"
                     island progress backup backup "Backing up" "$p" "to $(basename "$dest")"; fi ;;
            esac
        done
    rc=$(cat "$STATE_DIR/backup.rc" 2>/dev/null || echo 1); rm -f "$STATE_DIR/backup.rc"
    took=$(( $(date +%s) - start ))
    # 24 = some files vanished while copying (normal for a live system)
    if [ "$rc" = 0 ] || [ "$rc" = 24 ]; then
        mv -- "$part" "$new"
        if plainfs "$dest"; then printf '%s\n' "$stamp" > "$root/latest.txt"; else ln -sfn "$stamp" "$root/latest"; fi
        size=$(du -sb --apparent-size "$new" 2>/dev/null | cut -f1)
        save '.last = {time: ($t|tonumber), ok: true, snapshot: $s, size: ($z|tonumber), seconds: ($d|tonumber)}' \
            --arg t "$(date +%s)" --arg s "$stamp" --arg z "${size:-0}" --arg d "$took"
        # Keep the newest N: older snapshots go to the drive's trash, never straight to deletion
        keep=$(conf '.keep // 0')
        if [ "$keep" -gt 0 ] && command -v gio >/dev/null; then
            snapshots "$dest" | head -n -"$keep" | while IFS= read -r old; do gio trash -- "$root/$old" 2>/dev/null; done
        fi
        island progressDone backup "Backup finished" true "$stamp · $(( took / 60 ))m $(( took % 60 ))s"
        jq -cn --arg s "$stamp" '{p:100, st:"done", snapshot:$s}'
    else
        save '.last = ((.last // {}) + {time_failed: ($t|tonumber), ok: false})' --arg t "$(date +%s)"
        err=$(tail -n 3 "$STATE_DIR/backup.err" | tr '\n' ' ' | cut -c1-200)
        island progressDone backup "Backup failed" false "rsync exit $rc — the partial copy is kept"
        die "rsync stopped (exit $rc): ${err:-see $STATE_DIR/backup.err}. The partial copy is in $part."
    fi ;;
*)
    sed -n '2,26p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
