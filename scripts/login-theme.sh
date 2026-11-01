#!/bin/sh
# login-theme.sh — the login screen in Lumen's look (Settings → Appearance → Login screen).
#   login-theme.sh prepare           your wallpaper, sized to the screen, gently dimmed with a
#                                    vignette → ~/.cache/lumen/login-wallpaper.jpg (prints the path)
#   login-theme.sh apply             prepare, then hand it to the login screen (pkexec asks)
#   login-theme.sh remove            back to KDE's default (pkexec asks)
#   login-theme.sh status            JSON: {applied, image}
set -eu
LUMEN_ROOT=${LUMEN_ROOT:-$HOME/.config/lumen}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/lumen
OUT=${XDG_CACHE_HOME:-$HOME/.cache}/lumen/login-wallpaper.jpg
case ${1:-} in
    prepare)
        wp=$(cat "$STATE/wallpaper" 2>/dev/null || true)
        [ -f "$wp" ] || { echo "No wallpaper set" >&2; exit 1; }
        size=$(hyprctl -j monitors 2>/dev/null | jq -r '[.[] | select(.focused)][0] // .[0] | "\(.width)x\(.height)"' 2>/dev/null || true)
        case $size in *x*) ;; *) size=1920x1080 ;; esac
        mkdir -p "$(dirname "$OUT")"
        magick "$wp" -resize "${size}^" -gravity center -extent "$size" -modulate 88,106 \
            -background black -vignette 0x$(( ${size%x*} / 5 )) -quality 92 "$OUT"
        echo "$OUT" ;;
    apply)
        f=$("$0" prepare)
        pkexec "$LUMEN_ROOT/scripts/login-admin.sh" apply "$f" ;;
    remove)
        pkexec "$LUMEN_ROOT/scripts/login-admin.sh" remove ;;
    status)
        if [ -f /etc/plasmalogin.conf.d/50-lumen.conf ]; then a=true; else a=false; fi
        jq -cn --argjson a "$a" --arg i "$OUT" '{applied: $a, image: $i}' ;;
    *)
        sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
