#!/bin/sh
# screenshot.sh — capture the screen, a region, or the focused window.
#   screenshot.sh screen | region | window | edit | scroll
#   edit: pick a region, then annotate it in swappy (arrows, text, blur…)
#   scroll: pick a region, then scroll it yourself; run `scroll` again (the same
#           key) to finish — one long image (scripts/scrollshot.py)
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
    scroll)
        run=${XDG_RUNTIME_DIR:-/tmp}/lumen-scrollshot.pid
        ipc() { "${LUMEN_ROOT:-$HOME/.config/lumen}/bin/lumen-shell-ipc" island "$@" >/dev/null 2>&1 || true; }
        # The same key again: finish the one in progress
        if [ -s "$run" ] && kill -0 "$(cat "$run")" 2>/dev/null; then kill -TERM "$(cat "$run")"; exit 0; fi
        tokens=${LUMEN_ROOT:-$HOME/.config/lumen}/generated/tokens.json
        bg=$(jq -r '.colors.bg' "$tokens" 2>/dev/null || echo 0d1014)
        accent=$(jq -r '.colors.accent' "$tokens" 2>/dev/null || echo 52d1e9)
        geom=$(slurp -d -b "${bg}88" -c "${accent}ff" -w 2) || exit 0
        ipc progress scrollshot "Scrolling screenshot" -1 "Scroll slowly · Ctrl+Super+Shift+S again to finish"
        "${LUMEN_ROOT:-$HOME/.config/lumen}/scripts/scrollshot.py" "$geom" "$file" > "${run%.pid}.log" &
        echo $! > "$run"
        # Show it growing in the island while it runs
        while kill -0 "$(cat "$run")" 2>/dev/null; do
            h=$(tail -n1 "${run%.pid}.log" 2>/dev/null | jq -r '.height // empty' 2>/dev/null)
            [ -n "$h" ] && ipc progress scrollshot "Scrolling screenshot" -1 "${h} px · scroll slowly · press the key again to finish"
            sleep 0.6
        done
        rm -f "$run" "${run%.pid}.log"
        [ -s "$file" ] || { ipc progressDone scrollshot "Scrolling screenshot" false "Nothing captured"; exit 0; }
        ipc progressDone scrollshot "Scrolling screenshot" true "$(magick identify -format '%h px tall' "$file" 2>/dev/null)" ;;
    edit)
        command -v swappy >/dev/null || { echo "screenshot.sh: swappy not installed" >&2; exit 1; }
        tokens=${LUMEN_ROOT:-$HOME/.config/lumen}/generated/tokens.json
        bg=$(jq -r '.colors.bg' "$tokens" 2>/dev/null || echo 0d1014)
        accent=$(jq -r '.colors.accent' "$tokens" 2>/dev/null || echo 52d1e9)
        geom=$(slurp -d -b "${bg}88" -c "${accent}ff" -w 2) || exit 0
        grim -g "$geom" "$file"
        # Annotate; saving writes back to the same file, and it's copied too
        swappy -f "$file" -o "$file"
        [ -s "$file" ] || exit 0 ;;
    *)
        echo "usage: screenshot.sh screen|region|window|edit|scroll" >&2; exit 2 ;;
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
