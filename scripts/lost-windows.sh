#!/bin/sh
# lost-windows.sh — bring back floating windows that ended up off every screen
# (after unplugging a monitor, a resolution change, a stray drag). Each one is
# centred on the focused monitor. Prints how many it moved.
set -eu
lost=$(hyprctl -j clients | jq -c --argjson mons "$(hyprctl -j monitors)" '
  [ .[] | select(.floating and .mapped and (.workspace.id > 0)) as $c
    | select( [ $mons[] | select(
          ($c.at[0] + $c.size[0] > .x + 40) and ($c.at[0] < .x + (.width / .scale) - 40) and
          ($c.at[1] + $c.size[1] > .y + 40) and ($c.at[1] < .y + (.height / .scale) - 40)) ] | length == 0)
    | .address ]')
n=$(printf '%s' "$lost" | jq length)
[ "$n" -gt 0 ] || { echo 0; exit 0; }
mon=$(hyprctl -j monitors | jq -c '.[] | select(.focused)')
mx=$(printf '%s' "$mon" | jq '.x'); my=$(printf '%s' "$mon" | jq '.y')
mw=$(printf '%s' "$mon" | jq '(.width / .scale) | floor'); mh=$(printf '%s' "$mon" | jq '(.height / .scale) | floor')
ws=$(printf '%s' "$mon" | jq '.activeWorkspace.id')
for a in $(printf '%s' "$lost" | jq -r '.[]'); do
    size=$(hyprctl -j clients | jq -r --arg a "$a" '.[] | select(.address == $a) | "\(.size[0]) \(.size[1])"')
    w=${size% *}; h=${size#* }
    [ "$w" -gt "$mw" ] && w=$((mw * 3 / 4)); [ "$h" -gt "$mh" ] && h=$((mh * 3 / 4))
    hyprctl dispatch "hl.dsp.window.move({ workspace = $ws, follow = false, window = \"address:$a\" })" >/dev/null
    hyprctl dispatch "hl.dsp.focus({ window = \"address:$a\" })" >/dev/null
    hyprctl dispatch "hl.dsp.window.resize({ x = $w, y = $h, relative = false })" >/dev/null
    hyprctl dispatch "hl.dsp.window.move({ x = $((mx + (mw - w) / 2)), y = $((my + (mh - h) / 2)), relative = false })" >/dev/null
done
echo "$n"
