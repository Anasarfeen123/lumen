#!/bin/sh
# wallpaper.sh — wallpaper control.
#   wallpaper.sh init          remember a wallpaper on first run (shell draws it)
#   wallpaper.sh init --hyprpaper   ...and draw it with hyprpaper (no shell)
#   wallpaper.sh set <image>   switch wallpaper and remember it
#   wallpaper.sh get           print the current wallpaper path
#   wallpaper.sh list          "category<TAB>path" for every wallpaper found
#   wallpaper.sh thumbs        make missing 480 px thumbnails (low priority)
#   wallpaper.sh random        switch to a random wallpaper
#
# The Lumen shell watches the state file and cross-fades (modules/background).
# hyprpaper is only the fallback for running Hyprland without the shell.
# Library (sub-folders of ~/Pictures/Wallpapers are categories):
#   ~/Pictures/Wallpapers/<category>/…         your own
#   ~/.local/share/wallpapers, /usr/share/wallpapers   Plasma-style packages
#     (<name>/contents/images/<W>x<H>.ext — the largest size is used)
set -eu

STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/lumen
CURRENT=$STATE_DIR/wallpaper
CONF=${XDG_RUNTIME_DIR:-/tmp}/lumen-hyprpaper.conf

mkdir -p "$STATE_DIR"

current() {
    if [ -s "$CURRENT" ] && [ -f "$(cat "$CURRENT")" ]; then
        cat "$CURRENT"; return
    fi
    # First run: any image in the library, else the Plasma default wallpaper.
    for f in "$HOME"/Pictures/Wallpapers/* "$HOME"/.local/share/wallpapers/*; do
        case $f in *.jpg|*.jpeg|*.png|*.webp) [ -f "$f" ] && { echo "$f"; return; } ;; esac
    done
    return 1
}

start_hyprpaper() {
    printf 'splash = false\nipc = true\n\nwallpaper {\n    monitor =\n    path = %s\n    fit_mode = cover\n}\n' "$1" > "$CONF"
    # Only our instance: match the config path so another session's
    # hyprpaper is never touched.
    pkill -u "$(id -u)" -f "hyprpaper -c $CONF" 2>/dev/null || true
    hyprpaper -c "$CONF" >/dev/null 2>&1 &
}

THUMBS=${XDG_CACHE_HOME:-$HOME/.cache}/lumen/thumbs

is_image() { case $1 in *.jpg|*.jpeg|*.png|*.webp|*.JPG|*.JPEG|*.PNG|*.WEBP) return 0 ;; esac; return 1; }

list() {
    lib="$HOME/Pictures/Wallpapers"
    if [ -d "$lib" ]; then
        find "$lib" -type f 2>/dev/null | sort | while IFS= read -r f; do
            is_image "$f" || continue
            rel=${f#"$lib"/}
            case $rel in */*) cat=${rel%%/*} ;; *) cat="Wallpapers" ;; esac
            printf '%s\t%s\n' "$cat" "$f"
        done
    fi
    for root in "$HOME/.local/share/wallpapers" /usr/share/wallpapers; do
        [ -d "$root" ] || continue
        [ "$root" = /usr/share/wallpapers ] && cat="System" || cat="Plasma"
        for f in "$root"/*; do
            if [ -f "$f" ]; then
                is_image "$f" && printf '%s\t%s\n' "$cat" "$f"
            elif [ -d "$f/contents/images" ]; then
                # Plasma package: use its largest WxH image
                best=$(find "$f/contents/images" -maxdepth 1 -type f -name '*x*.*' -printf '%f\n' 2>/dev/null |
                       awk -F'[x.]' '$1 ~ /^[0-9]+$/ && $2 ~ /^[0-9]+$/ {print $1*$2 "\t" $0}' | sort -n | tail -1 | cut -f2)
                [ -n "$best" ] && printf '%s\t%s\n' "$cat" "$f/contents/images/$best"
            elif [ -d "$f" ]; then
                # Plain folder of images (e.g. a theme's wallpaper pack)
                find "$f" -maxdepth 1 -type f | sort | while IFS= read -r g; do
                    is_image "$g" && printf '%s\t%s\n' "$cat" "$g"
                done
            fi
        done
    done
}

thumb_path() { printf '%s/%s.jpg' "$THUMBS" "$(printf '%s' "$1" | md5sum | cut -c1-32)"; }

case ${1:-} in
    list)
        list ;;
    thumbs)
        mkdir -p "$THUMBS"
        command -v magick >/dev/null 2>&1 || exit 0
        list | cut -f2 | while IFS= read -r f; do
            t=$(thumb_path "$f")
            [ -s "$t" ] || nice -n 19 magick "${f}[0]" -auto-orient -thumbnail 480x270^ -gravity center -extent 480x270 -quality 82 "$t" 2>/dev/null
        done ;;
    random)
        cur=$(cat "$CURRENT" 2>/dev/null || true)
        pick=$(list | cut -f2 | grep -vxF "$cur" | shuf -n 1)
        [ -n "$pick" ] && exec "$0" set "$pick" ;;
    init)
        wp=$(current) || { echo "wallpaper.sh: no wallpaper found; using background colour" >&2; exit 0; }
        [ -s "$CURRENT" ] || printf '%s\n' "$wp" > "$CURRENT"   # remember first-run pick
        [ "${2:-}" = --hyprpaper ] && start_hyprpaper "$wp"
        exit 0 ;;
    set)
        [ -f "${2:-}" ] || { echo "wallpaper.sh: not a file: ${2:-}" >&2; exit 1; }
        wp=$(realpath "$2")
        printf '%s\n' "$wp" > "$CURRENT"   # in place: the shell watches this file
        # Fallback renderer: refresh it only if it is the one drawing
        if pgrep -u "$(id -u)" -f "hyprpaper -c $CONF" >/dev/null 2>&1; then start_hyprpaper "$wp"; fi ;;
    get)
        current ;;
    *)
        sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
