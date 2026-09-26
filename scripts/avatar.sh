#!/bin/sh
# avatar.sh — your picture on the lock screen (~/.face).
#   avatar.sh pick     choose an image (file dialog), crop it square, save
#   avatar.sh set <f>  same, from a file
#   avatar.sh remove   back to your initial
# The original is never modified; ~/.face gets a 256 px square copy.
set -eu
out="$HOME/.face"
case ${1:-} in
    pick)
        f=$(kdialog --title "Lock screen picture" --getopenfilename "$HOME/Pictures" "image/png image/jpeg image/webp" 2>/dev/null \
            || zenity --file-selection --title "Lock screen picture" --file-filter "Images | *.png *.jpg *.jpeg *.webp" 2>/dev/null) || exit 0
        exec "$0" set "$f" ;;
    set)
        [ -f "${2:-}" ] || { echo "avatar.sh: no such file" >&2; exit 1; }
        tmp=$(mktemp "$out.XXXXXX.png")
        magick "$2" -auto-orient -resize 256x256^ -gravity center -extent 256x256 "$tmp"
        mv "$tmp" "$out" ;;
    remove)
        rm -f "$out" ;;
    *)
        sed -n '3,5p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
