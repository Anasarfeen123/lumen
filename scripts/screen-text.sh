#!/bin/sh
# screen-text.sh — select part of the screen, copy the text in it (OCR).
# Local only: grim → tesseract → clipboard. The image lives in
# $XDG_RUNTIME_DIR for a moment and is deleted straight away.
#   screen-text.sh [lang]     lang: tesseract language(s), default "eng"
set -u
LUMEN_ROOT=${LUMEN_ROOT:-$HOME/.config/lumen}
ipc() { "$LUMEN_ROOT/bin/lumen-shell-ipc" island "$@" >/dev/null 2>&1 || true; }
lang=${1:-eng}

command -v tesseract >/dev/null || { ipc event "text_fields" "Text recognition unavailable" "Install tesseract"; exit 1; }

tokens="$LUMEN_ROOT/generated/tokens.json"
bg=$(jq -r '.colors.bg' "$tokens" 2>/dev/null || echo 0d1014)
accent=$(jq -r '.colors.accent' "$tokens" 2>/dev/null || echo 52d1e9)
geom=$(slurp -d -b "${bg}88" -c "${accent}ff" -w 2) || exit 0     # Esc: cancel quietly

img=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/lumen-ocr-XXXXXX.png") || exit 1
trap 'rm -f "$img"' EXIT
grim -g "$geom" -s 2 "$img" || exit 1                               # 2× scale reads small text better

text=$(tesseract "$img" - -l "$lang" --psm 6 2>/dev/null | sed -e 's/[[:space:]]*$//' | sed -e '/./,$!d')
if [ -z "$(printf '%s' "$text" | tr -d '[:space:]')" ]; then
    ipc event "text_fields" "No text found" "Try a larger area"
    exit 0
fi
printf '%s' "$text" | wl-copy
words=$(printf '%s' "$text" | wc -w)
preview=$(printf '%s' "$text" | tr '\n' ' ' | cut -c1-48)
ipc event "content_copy" "Copied $words word$( [ "$words" -eq 1 ] || echo s)" "$preview"
