#!/bin/sh
# halo-context.sh — read-only context for Lumen Halo, printed as plain text
# that goes into the prompt. Nothing here changes the system; nothing here is
# sent anywhere by itself (Halo only sends it when you ask, with the chip on).
#
#   halo-context.sh system           network, failed services, recent errors, disk, memory, load, battery
#   halo-context.sh project <dir>    git branch/status, recent commits, the diff (staged, else unstaged)
#   halo-context.sh clipboard        the clipboard's text (first 8 KB)
#   halo-context.sh window           the focused window: app, title, workspace
#   halo-context.sh file <path>      a file's text: PDFs (pdftotext), text/code, office documents
#                                    (LibreOffice, if installed); images print "@@IMAGE@@ <jpeg>"
#                                    (a scaled private copy Halo attaches for a vision model)
#   halo-context.sh downloads        the 12 newest files in ~/Downloads, as JSON lines {path,name,size,mtime}
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
window)
    hyprctl -j activewindow 2>/dev/null | jq -r '"## Focused window\napp: \(.class)\ntitle: \(.title)\nworkspace: \(.workspace.name)"' 2>/dev/null ;;
file)
    f=${2:-}
    [ -f "$f" ] && [ -r "$f" ] || { echo "(can't read ${f##*/})"; exit 0; }
    name=${f##*/}
    mime=$(file --mime-type -b -- "$f" 2>/dev/null)
    limit=${HALO_LIMIT:-12000}; case $limit in *[!0-9]*|"") limit=12000 ;; esac
    # Text, truncated with a clear note
    emit() {
        out=$(head -c "$((limit + 1))")
        printf '## File: %s (%s)\n' "$name" "$mime"
        if [ "$(printf '%s' "$out" | wc -c)" -gt "$limit" ]; then printf '%s\n[… truncated: only the first %s characters are shown]\n' "$(printf '%s' "$out" | head -c "$limit")" "$limit"
        else printf '%s\n' "$out"; fi
    }
    case $mime in
    application/pdf)
        command -v pdftotext >/dev/null || { echo "(PDF text needs poppler-utils: sudo dnf install poppler-utils)"; exit 0; }
        pages=$(pdfinfo -- "$f" 2>/dev/null | awk '/^Pages:/ {print $2}')
        [ -n "$pages" ] && printf '(%s pages)\n' "$pages"
        pdftotext -layout -l 40 -- "$f" - 2>/dev/null | tr -s ' \n' | emit ;;
    image/*)
        dir=${XDG_RUNTIME_DIR:-/tmp}/lumen-ai; mkdir -p "$dir"; chmod 700 "$dir"
        out="$dir/file-$(date +%s%N).jpg"
        if magick "${f}[0]" -resize '1568x1568>' -quality 85 "$out" 2>/dev/null; then
            printf '@@IMAGE@@ %s\n## Image: %s\n' "$out" "$name"
        else echo "(couldn't read the image ${name})"; fi ;;
    application/vnd.openxmlformats-officedocument.*|application/vnd.oasis.opendocument.*|application/msword|application/vnd.ms-*|application/rtf)
        command -v libreoffice >/dev/null || { echo "(Office documents need LibreOffice)"; exit 0; }
        tmp=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/lumen-ai-doc.XXXXXX")
        libreoffice --headless --convert-to txt:Text --outdir "$tmp" -- "$f" >/dev/null 2>&1
        cat "$tmp"/*.txt 2>/dev/null | emit
        rm -rf -- "$tmp" ;;
    text/*|application/json|application/xml|application/javascript|application/x-sh|application/x-shellscript|application/toml|application/x-yaml|inode/x-empty)
        emit < "$f" ;;
    *)
        # Anything else that is mostly text
        if head -c 4096 -- "$f" | grep -qI .; then emit < "$f"
        else printf '## File: %s (%s, %s bytes) — not a text document\n' "$name" "$mime" "$(stat -c %s -- "$f")"; fi ;;
    esac ;;
downloads)
    d=$(xdg-user-dir DOWNLOAD 2>/dev/null || echo "$HOME/Downloads")
    [ -d "$d" ] || exit 0
    find "$d" -maxdepth 1 -type f ! -name '.*' ! -name '*.part' ! -name '*.crdownload' -printf '%T@\t%s\t%p\n' 2>/dev/null |
        sort -rn | head -n 12 |
        while IFS="$(printf '\t')" read -r t size path; do
            jq -cn --arg p "$path" --argjson s "$size" --argjson t "${t%.*}" '{path:$p, name:($p|split("/")|last), size:$s, mtime:$t}'
        done ;;
clipboard)
    wl-paste --no-newline --type text 2>/dev/null | cap 8000 ;;
*)
    sed -n '5,14p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
