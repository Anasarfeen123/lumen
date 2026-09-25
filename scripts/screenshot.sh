#!/bin/sh
# screenshot.sh — capture the screen, a region, or the focused window.
#   screenshot.sh screen | region | window
# Saves to $XDG_PICTURES_DIR/Screenshots and copies the image to the clipboard.
# The island shows a confirmation; a notification also goes to history.
set -eu

mode=${1:-screen}
pics=$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")
dir="$pics/Screenshots"
mkdir -p "$dir"
file="$dir/$(date +%Y-%m-%d_%H-%M-%S).png"

case $mode in
    screen)
        # Focused monitor only
        output=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
        grim -o "$output" "$file" ;;
    region)
        # Selection colours come from the design tokens.
        tokens=${LUMEN_ROOT:-$HOME/.config/lumen}/generated/tokens.json
        bg=$(jq -r '.colors.bg' "$tokens" 2>/dev/null || echo 0d1014)
        accent=$(jq -r '.colors.accent' "$tokens" 2>/dev/null || echo 52d1e9)
        # Esc in slurp cancels: exit quietly, no notification
        geom=$(slurp -d -b "${bg}88" -c "${accent}ff" -w 2) || exit 0
        grim -g "$geom" "$file" ;;
    window)
        geom=$(hyprctl activewindow -j | jq -r 'if .at then "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])" else empty end')
        [ -n "$geom" ] || exit 0
        grim -g "$geom" "$file" ;;
    *)
        echo "usage: screenshot.sh screen|region|window" >&2; exit 2 ;;
esac

wl-copy --type image/png < "$file"

# Island confirmation (thumbnail; click opens the file)
"${LUMEN_ROOT:-$HOME/.config/lumen}/bin/lumen-shell-ipc" island screenshot "$file" >/dev/null 2>&1 || true

# Non-blocking: open the file if the notification's action is clicked.
(
    action=$(notify-send -a Screenshot -i "$file" -h string:x-lumen-kind:screenshot \
        -A open=Open "Screenshot copied" "${file##*/}" 2>/dev/null) || exit 0
    [ "$action" = open ] && xdg-open "$file"
) >/dev/null 2>&1 &
