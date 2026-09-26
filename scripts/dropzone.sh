#!/bin/sh
# dropzone.sh — what Drop Zone does with the files you drop on it.
#   dropzone.sh copy FILE…            put them on the clipboard as files (paste into a file manager or chat)
#   dropzone.sh compress FILE…        a .zip next to the first file; prints its path
#   dropzone.sh move DEST FILE…       DEST: documents|downloads|desktop|pictures|projects; never overwrites
#   dropzone.sh send ID FILE…         to a phone through KDE Connect
#   dropzone.sh open DESKTOP-ID FILE… open them with that app
#   dropzone.sh apps FILE             apps that open this type, default first: JSON [{id,name,icon,isDefault}]
#   dropzone.sh phone                 the first reachable phone: JSON {id,name} or null
# Nothing here uploads anything anywhere; "send" only talks to your own paired phone.
set -u

need_files() {
    [ $# -gt 0 ] || { echo "no files" >&2; exit 2; }
    for f; do [ -e "$f" ] || { echo "missing: $f" >&2; exit 1; }; done
}

case ${1:-} in
copy)
    shift; need_files "$@"
    for f; do
        p=$(realpath -- "$f")
        # file:// URI with the characters that must be escaped (space, %, #, ?)
        printf 'file://%s\r\n' "$(printf '%s' "$p" | sed -e 's/%/%25/g' -e 's/ /%20/g' -e 's/#/%23/g' -e 's/?/%3F/g')"
    done | wl-copy --type text/uri-list
    echo ok ;;
compress)
    shift; need_files "$@"
    first=$(realpath -- "$1"); dir=$(dirname -- "$first")
    same=1; for f; do [ "$(dirname -- "$(realpath -- "$f")")" = "$dir" ] || same=0; done
    if [ $# -eq 1 ]; then
        base=$(basename -- "$first"); name=$base
        [ -d "$first" ] || { case $base in ?*.*) name=${base%.*} ;; esac; }
    else
        name="Archive $(date '+%Y-%m-%d %H.%M')"
    fi
    out="$dir/$name.zip"; n=2
    while [ -e "$out" ]; do out="$dir/$name ($n).zip"; n=$((n + 1)); done
    if [ $same -eq 1 ]; then
        # relative names, so the archive holds "report.pdf", not "/home/…/report.pdf"
        for f; do shift; set -- "$@" "$(basename -- "$f")"; done
        (cd "$dir" && zip -rqy "$out" -- "$@") || { echo "zip failed" >&2; exit 1; }
    else
        zip -rqyj "$out" -- "$@" || { echo "zip failed" >&2; exit 1; }
    fi
    printf '%s\n' "$out" ;;
move)
    shift; dest=${1:-}; shift
    case $dest in
        documents) d=$(xdg-user-dir DOCUMENTS 2>/dev/null) ;;
        downloads) d=$(xdg-user-dir DOWNLOAD 2>/dev/null) ;;
        desktop)   d=$(xdg-user-dir DESKTOP 2>/dev/null) ;;
        pictures)  d=$(xdg-user-dir PICTURES 2>/dev/null) ;;
        projects)  d=$HOME/Projects ;;
        *) echo "unknown destination" >&2; exit 2 ;;
    esac
    [ -n "$d" ] && [ "$d" != "$HOME" ] || d=$HOME/$(printf '%s' "$dest" | sed 's/./\U&/')
    need_files "$@"
    mkdir -p -- "$d"
    moved=0; skipped=0
    for f; do
        t="$d/$(basename -- "$f")"
        if [ -e "$t" ] || [ "$(realpath -- "$f")" = "$(realpath -m -- "$t")" ]; then skipped=$((skipped + 1)); continue; fi
        mv -n -- "$f" "$d/" && [ ! -e "$f" ] && moved=$((moved + 1)) || skipped=$((skipped + 1))
    done
    printf '%s %s %s\n' "$moved" "$skipped" "$d" ;;
send)
    shift; id=${1:-}; shift
    printf '%s' "$id" | grep -Eq '^[A-Za-z0-9_]+$' || { echo "bad device id" >&2; exit 2; }
    need_files "$@"
    for f; do kdeconnect-cli -d "$id" --share "$(realpath -- "$f")" >/dev/null 2>&1 || exit 1; done
    echo ok ;;
open)
    shift; app=${1:-}; shift
    printf '%s' "$app" | grep -Eq '^[A-Za-z0-9._-]+$' || { echo "bad app id" >&2; exit 2; }
    need_files "$@"
    exec gtk-launch "${app%.desktop}" "$@" ;;
apps)
    f=${2:-}; [ -e "$f" ] || { echo '[]'; exit 0; }
    mime=$(xdg-mime query filetype "$f" 2>/dev/null)
    [ -d "$f" ] && mime=inode/directory
    def=$(xdg-mime query default "$mime" 2>/dev/null)
    dirs="${XDG_DATA_HOME:-$HOME/.local/share}:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
    ids=$( { printf '%s\n' "$def"
             IFS=:; for d in $dirs; do
                 c="$d/applications/mimeinfo.cache"
                 [ -f "$c" ] && grep -m1 "^$mime=" "$c" 2>/dev/null | cut -d= -f2 | tr ';' '\n'
             done; } | grep -v '^$' | awk '!seen[$0]++' | head -n 6)
    for id in $ids; do
        file=""
        IFS=:; for d in $dirs; do [ -f "$d/applications/$id" ] && { file="$d/applications/$id"; break; }; done; unset IFS
        [ -n "$file" ] || continue
        grep -q '^NoDisplay=true' "$file" && [ "$id" != "$def" ] && continue
        name=$(sed -n '/^\[Desktop Entry\]/,/^\[/{s/^Name=//p}' "$file" | head -n 1)
        icon=$(sed -n '/^\[Desktop Entry\]/,/^\[/{s/^Icon=//p}' "$file" | head -n 1)
        jq -cn --arg id "$id" --arg n "$name" --arg i "$icon" --argjson d "$([ "$id" = "$def" ] && echo true || echo false)" \
            '{id:$id, name:$n, icon:$i, isDefault:$d}'
    done | jq -sc '.[0:5]' ;;
phone)
    command -v kdeconnect-cli >/dev/null 2>&1 || { echo null; exit 0; }
    kdeconnect-cli -a --id-name-only 2>/dev/null | head -n 1 |
        awk 'NF { id=$1; $1=""; sub(/^ /,""); printf "{\"id\":\"%s\",\"name\":\"%s\"}\n", id, $0; found=1 } END { if (!found) print "null" }' ;;
*)
    sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
