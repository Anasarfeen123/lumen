#!/bin/sh
# lens.sh — Circle to search's hands (shell/services/Lens.qml). Local only:
# the frozen screen and the piece you circled live in $XDG_RUNTIME_DIR/lumen-lens
# (RAM, private) and are deleted when the overlay closes.
#   lens.sh shot <monitor> <out.png>          freeze one monitor (grim)
#   lens.sh crop <in> <x> <y> <w> <h> <out>   cut out the circled piece (pixels)
#   lens.sh ocr <img> [lang]                  the text in it (tesseract), on stdout
#   lens.sh copy-image <img>                  put it on the clipboard
#   lens.sh google <img>                      copy it, then open Google Lens's upload box (you paste)
#   lens.sh save <img>                        keep it in ~/Pictures/Screenshots, prints the path
set -u
dir=${XDG_RUNTIME_DIR:-/tmp}/lumen-lens

case ${1:-} in
shot)
    mkdir -p "$dir" && chmod 700 "$dir"
    grim -o "$2" "$3" && chmod 600 "$3"
    ;;
crop)
    magick "$2" -crop "${5}x${6}+${3}+${4}" +repage "$7" && chmod 600 "$7"
    ;;
ocr)
    command -v tesseract >/dev/null || exit 3
    lang=${3:-eng}
    big="$dir/ocr-$$.png"
    trap 'rm -f "$big"' EXIT
    # small text reads better twice the size
    magick "$2" -resize 200% "$big" 2>/dev/null || cp "$2" "$big"
    text=$(tesseract "$big" - -l "$lang" --psm 3 2>/dev/null)
    [ -z "$(printf '%s' "$text" | tr -d '[:space:]')" ] && text=$(tesseract "$big" - -l "$lang" --psm 6 2>/dev/null)
    printf '%s' "$text" | sed -e 's/[[:space:]]*$//' | sed -e '/./,$!d' | cat -s
    ;;
copy-image)
    wl-copy --type image/png < "$2"
    ;;
google)
    wl-copy --type image/png < "$2"
    xdg-open "https://www.google.com/?olud" >/dev/null 2>&1 &
    ;;
save)
    out="${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots"
    mkdir -p "$out"
    f="$out/Lens_$(date +%Y-%m-%d_%H-%M-%S).png"
    cp "$2" "$f" && printf '%s\n' "$f"
    ;;
clean)
    rm -rf "$dir"
    ;;
*)
    sed -n '2,12p' "$0"; exit 2 ;;
esac
