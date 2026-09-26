#!/bin/sh
# display-mode.sh — the "project" key (Fn+F9 / Super+P) and Settings.
#   display-mode.sh next      step to the next mode that makes sense now
#   display-mode.sh extend | mirror | external | laptop
#   display-mode.sh status    the current mode
# Prints one JSON line for the island: {"mode":…,"label":…,"detail":…}
# Changes are live only (hyprctl eval); monitors.lua / local.lua stay the
# config you log in with. "External only" is undone automatically when the
# external screen goes away (the shell watches for that).
set -u
STATE=${XDG_RUNTIME_DIR:-/tmp}/lumen-display-mode

mons=$(hyprctl -j monitors all 2>/dev/null) || { echo '{"mode":"error","label":"Displays","detail":"Hyprland isn'"'"'t answering"}'; exit 1; }
internal=$(printf '%s' "$mons" | jq -r '[.[] | select(.name | test("^(eDP|LVDS|DSI)"))][0].name // empty')
external=$(printf '%s' "$mons" | jq -r '[.[] | select(.name | test("^(eDP|LVDS|DSI|HEADLESS|WAYLAND|LUMENTEST)") | not)][0].name // empty')
extdesc=$(printf '%s' "$mons" | jq -r --arg n "$external" '.[] | select(.name == $n) | .description' | sed 's/ (.*)$//; s/  */ /g' | cut -c1-40)

out() { jq -cn --arg m "$1" --arg l "$2" --arg d "$3" '{mode:$m, label:$l, detail:$d}'; }

if [ -z "$external" ] || [ -z "$internal" ]; then
    out single "One display" "Connect a screen to extend or mirror"
    exit 0
fi

current=$(cat "$STATE" 2>/dev/null || echo extend)
mode=${1:-status}
case $mode in
    status) out "$current" "$current" "$extdesc"; exit 0 ;;
    next)
        case $current in
            extend) mode=mirror ;;
            mirror) mode=external ;;
            external) mode=laptop ;;
            *) mode=extend ;;
        esac ;;
    extend|mirror|external|laptop) ;;
    *) echo "usage: display-mode.sh next|extend|mirror|external|laptop|status" >&2; exit 2 ;;
esac

# The internal panel's own mode (remembered while it's on, so it comes back as it was)
imode=$(printf '%s' "$mons" | jq -r --arg n "$internal" '.[] | select(.name == $n and (.disabled | not)) | "\(.width)x\(.height)@\(.refreshRate | floor)"')
[ -n "$imode" ] && printf '%s' "$imode" > "$STATE.internal"
imode=$(cat "$STATE.internal" 2>/dev/null || echo preferred)

ev() { hyprctl eval "$1" >/dev/null 2>&1; }
laptop_on() { ev "hl.monitor({ output = \"$internal\", mode = \"$imode\", position = \"0x0\", scale = 1 })"; }
case $mode in
    extend)   laptop_on; ev "hl.monitor({ output = \"$external\", mode = \"preferred\", position = \"auto-right\", scale = 1 })"
              label="Extend"; detail="Laptop and $extdesc side by side" ;;
    mirror)   laptop_on; ev "hl.monitor({ output = \"$external\", mode = \"preferred\", position = \"auto\", scale = 1, mirror = \"$internal\" })"
              label="Mirror"; detail="$extdesc shows the laptop screen" ;;
    external) ev "hl.monitor({ output = \"$external\", mode = \"preferred\", position = \"0x0\", scale = 1 })"
              ev "hl.monitor({ output = \"$internal\", disabled = true })"
              label="External only"; detail="$extdesc · laptop screen off" ;;
    laptop)   laptop_on; ev "hl.monitor({ output = \"$external\", disabled = true })"
              label="Laptop only"; detail="$extdesc off" ;;
esac
printf '%s' "$mode" > "$STATE"
out "$mode" "$label" "$detail"
