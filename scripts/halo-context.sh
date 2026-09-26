#!/bin/sh
# halo-context.sh — read-only context for Lumen Halo, printed as plain text
# that goes into the prompt. Nothing here changes the system; nothing here is
# sent anywhere by itself (Halo only sends it when you ask, with the chip on).
#
#   halo-context.sh system           network, failed services, recent errors, disk, memory, load, battery
#   halo-context.sh project <dir>    git branch/status, recent commits, the diff (staged, else unstaged)
#   halo-context.sh clipboard        the clipboard's text (first 8 KB)
set -u

section() { printf '\n### %s\n' "$1"; }
cap() { head -c "${1:-4000}"; }

case ${1:-} in
system)
    printf '## System snapshot (%s)\n' "$(date '+%Y-%m-%d %H:%M')"
    section "OS"
    . /etc/os-release 2>/dev/null && printf '%s, kernel %s, %s\n' "${PRETTY_NAME:-Linux}" "$(uname -r)" "$(uptime -p 2>/dev/null)"
    section "Network"
    nmcli -t -f DEVICE,TYPE,STATE,CONNECTION device 2>/dev/null | grep -v ':unmanaged' | cap 1200
    nmcli -t -f CONNECTIVITY general 2>/dev/null | sed 's/^/connectivity: /'
    ip -brief -4 addr 2>/dev/null | grep -v '^lo ' | cap 600
    printf 'dns: %s\n' "$(resolvectl dns 2>/dev/null | awk -F': ' 'NF>1 && $2!="" {print $2}' | tr '\n' ' ' | cap 200)"
    section "Failed services"
    { systemctl --failed --no-legend --plain 2>/dev/null; systemctl --user --failed --no-legend --plain 2>/dev/null; } | awk '{print $1}' | cap 800
    section "Errors this boot (latest 30)"
    journalctl -b -p err --no-pager -q -n 30 -o short-monotonic 2>/dev/null | cut -c1-220 | cap 5000
    section "Disk"
    df -h -x tmpfs -x devtmpfs -x efivarfs -x squashfs --output=target,size,used,avail,pcent 2>/dev/null | cap 800
    section "Memory and load"
    free -h 2>/dev/null | cap 400
    printf 'load: %s\n' "$(cut -d' ' -f1-3 /proc/loadavg)"
    section "Top processes (CPU)"
    ps -eo pid,comm,%cpu,%mem --sort=-%cpu 2>/dev/null | head -n 8
    for b in /sys/class/power_supply/BAT*; do
        [ -d "$b" ] || continue
        section "Battery"
        printf '%s%%, %s, health %s\n' "$(cat "$b/capacity" 2>/dev/null)" "$(cat "$b/status" 2>/dev/null)" \
            "$(awk -v f="$(cat "$b/energy_full" 2>/dev/null || cat "$b/charge_full" 2>/dev/null)" -v d="$(cat "$b/energy_full_design" 2>/dev/null || cat "$b/charge_full_design" 2>/dev/null)" 'BEGIN{ if (d>0) printf "%d%%", f*100/d; else print "?" }')"
        break
    done ;;
project)
    dir=${2:-}
    [ -d "$dir" ] || { echo "No project folder."; exit 0; }
    top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || { printf '## Folder %s (not a git repository)\n' "$dir"; ls -1 "$dir" | head -n 40; exit 0; }
    printf '## Project %s\n' "$(basename "$top")"
    section "Branch and status"
    git -C "$top" status --short --branch 2>/dev/null | cap 2000
    section "Recent commits"
    git -C "$top" log --oneline -n 8 2>/dev/null
    if ! git -C "$top" diff --cached --quiet 2>/dev/null; then
        section "Staged diff"
        git -C "$top" diff --cached --stat 2>/dev/null | cap 1500
        git -C "$top" diff --cached 2>/dev/null | cap 12000
    else
        section "Unstaged diff"
        git -C "$top" diff --stat 2>/dev/null | cap 1500
        git -C "$top" diff 2>/dev/null | cap 12000
    fi ;;
clipboard)
    wl-paste --no-newline --type text 2>/dev/null | cap 8000 ;;
*)
    sed -n '5,8p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
