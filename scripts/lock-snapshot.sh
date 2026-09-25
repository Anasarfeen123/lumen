#!/bin/sh
# lock-snapshot.sh — screenshots used only for the lock/unlock transitions.
#   lock-snapshot.sh take  <dir>   one JPEG per output: <dir>/<output>.jpg
#   lock-snapshot.sh clear <dir>   delete them
#
# The directory lives in $XDG_RUNTIME_DIR (a tmpfs only this user can read),
# is created 0700, and is emptied as soon as the unlock animation finishes.
# The lock itself never depends on this: if capture fails, locking proceeds.
set -u

dir=${2:-${XDG_RUNTIME_DIR:-/tmp}/lumen-lock/${HYPRLAND_INSTANCE_SIGNATURE:-default}}

case ${1:-} in
    take)
        umask 077
        mkdir -p "$dir" && chmod 700 "${dir%/*}" "$dir" || exit 1
        rm -f "$dir"/*.jpg
        outputs=$(hyprctl monitors -j 2>/dev/null | jq -r '.[].name') || exit 1
        [ -n "$outputs" ] || exit 1
        for o in $outputs; do
            grim -o "$o" -t jpeg -q 88 "$dir/$o.jpg" &
        done
        wait
        ls "$dir"/*.jpg >/dev/null 2>&1 ;;
    clear)
        rm -f "$dir"/*.jpg ;;
    *)
        echo "usage: lock-snapshot.sh take|clear [dir]" >&2; exit 2 ;;
esac
