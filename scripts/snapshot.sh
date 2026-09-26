#!/bin/sh
# snapshot.sh — save and restore a whole setup of windows.
#   snapshot.sh save <name>      apps, workspaces, floating geometry, terminal folders,
#                                Focus mode and wallpaper → ~/.local/state/lumen/snapshots/<name>.json
#   snapshot.sh restore <name>   relaunch what isn't already open, onto the same workspaces
#   snapshot.sh list             JSON: [{name, windows, saved}]
#   snapshot.sh delete <name>
# Apps are relaunched from their desktop entry when one matches (Flatpaks
# included), otherwise from their original command line. Browsers reopen
# their own tabs through their session restore.
set -eu
DIR=${XDG_STATE_HOME:-$HOME/.local/state}/lumen/snapshots
mkdir -p "$DIR"
name() { printf '%s' "${1:?name}" | tr -cd 'A-Za-z0-9 _.-' | tr ' ' '_' | cut -c1-40; }
ipc="${LUMEN_ROOT:-$HOME/.config/lumen}/bin/lumen-shell-ipc"

# desktop-file id for a window class (StartupWMClass, then file name)
desktop_for() {
    for d in "$HOME/.local/share/applications" /usr/share/applications /var/lib/flatpak/exports/share/applications "$HOME/.local/share/flatpak/exports/share/applications"; do
        [ -d "$d" ] || continue
        f=$(grep -lis "^StartupWMClass=$1\$" "$d"/*.desktop 2>/dev/null | head -1)
        [ -n "$f" ] || f=$(ls "$d" 2>/dev/null | grep -ix "$1.desktop" | head -1 | sed "s|^|$d/|")
        [ -n "$f" ] || f=$(ls "$d" 2>/dev/null | grep -i "\.$1\.desktop\$" | head -1 | sed "s|^|$d/|")
        [ -n "$f" ] && { basename "$f" .desktop; return; }
    done
}

case ${1:-} in
save)
    n=$(name "${2:-}")
    mon=$(hyprctl -j monitors)
    hyprctl -j clients | jq -c '.[] | select(.workspace.id > 0 and .mapped)' | while IFS= read -r c; do
        class=$(printf '%s' "$c" | jq -r .class); pid=$(printf '%s' "$c" | jq -r .pid)
        cwd=""
        case $class in kitty|foot|Alacritty|org.wezfurlong.wezterm|com.mitchellh.ghostty|org.kde.konsole|konsole)
            for ch in $(pgrep -P "$pid" 2>/dev/null); do
                case $(cat "/proc/$ch/comm" 2>/dev/null) in bash|zsh|fish|sh|nu) cwd=$(readlink "/proc/$ch/cwd" 2>/dev/null) ;; esac
            done ;;
        esac
        desk=$(desktop_for "$class")
        cmd=$(tr '\0' '\n' < "/proc/$pid/cmdline" 2>/dev/null | jq -R -s -c 'split("\n") | map(select(length > 0))' || echo '[]')
        printf '%s' "$c" | jq -c --arg cwd "$cwd" --arg desk "${desk:-}" --argjson cmd "$cmd" --argjson mon "$mon" '
            (.monitor) as $m | ($mon | map(select(.id == $m)) | .[0] // {x: 0, y: 0}) as $mm |
            {class, title, workspace: .workspace.id, floating, at: [(.at[0] - $mm.x), (.at[1] - $mm.y)], size,
             cwd: $cwd, desktop: $desk, cmd: $cmd}'
    done | jq -s -c --arg name "$n" --arg focus "$("$ipc" focus get 2>/dev/null || echo off)" \
            --arg wall "$(cat "${XDG_STATE_HOME:-$HOME/.local/state}/lumen/wallpaper" 2>/dev/null)" \
            '{name: $name, saved: (now | floor), focus: $focus, wallpaper: $wall, windows: .}' > "$DIR/$n.json"
    count=$(jq '.windows | length' "$DIR/$n.json")
    "$ipc" island event bookmark_added "Saved “$n”" "$count windows" >/dev/null 2>&1 || true
    echo "saved $n ($count windows)" ;;
restore)
    n=$(name "${2:-}"); f="$DIR/$n.json"
    [ -f "$f" ] || { echo "no snapshot '$n'" >&2; exit 1; }
    running=$(hyprctl -j clients | jq -c '[.[] | {class, ws: .workspace.id}]')
    jq -c '.windows[]' "$f" | while IFS= read -r w; do
        class=$(printf '%s' "$w" | jq -r .class); ws=$(printf '%s' "$w" | jq -r .workspace)
        # already open on that workspace → leave it
        printf '%s' "$running" | jq -e --arg c "$class" --argjson ws "$ws" 'any(.[]; .class == $c and .ws == $ws)' >/dev/null && continue
        cwd=$(printf '%s' "$w" | jq -r .cwd); desk=$(printf '%s' "$w" | jq -r .desktop)
        if [ -n "$cwd" ] && [ "$class" = kitty ]; then launch="kitty --directory '$(printf '%s' "$cwd" | sed "s/'/'\\\\''/g")'"
        elif [ -n "$desk" ]; then launch="gtk-launch $desk"
        else launch=$(printf '%s' "$w" | jq -r '.cmd | map(@sh) | join(" ")'); fi
        [ -n "$launch" ] || continue
        rules=$(printf '%s' "$w" | jq -r --argjson ws "$ws" '"{ workspace = \"\($ws) silent\"" +
            (if .floating then ", float = true, size = \"\(.size[0]) \(.size[1])\", move = \"\(.at[0]) \(.at[1])\"" else "" end) + " }"')
        esc=$(printf '%s' "$launch" | sed 's/\\/\\\\/g; s/"/\\"/g')
        hyprctl dispatch "hl.dsp.exec_cmd(\"$esc\", $rules)" >/dev/null
        sleep 0.15
    done
    focus=$(jq -r .focus "$f"); [ "$focus" != off ] && [ "$focus" != null ] && "$ipc" focus set "$focus" >/dev/null 2>&1 || true
    wall=$(jq -r .wallpaper "$f"); [ -f "$wall" ] && "${LUMEN_ROOT:-$HOME/.config/lumen}/scripts/wallpaper.sh" set "$wall" >/dev/null 2>&1 || true
    "$ipc" island event bookmark "Restored “$n”" "$(jq '.windows | length' "$f") windows" >/dev/null 2>&1 || true ;;
list)
    for f in "$DIR"/*.json; do [ -f "$f" ] && jq -c '{name, saved, windows: (.windows | length), apps: ([.windows[].class] | unique)}' "$f"; done | jq -s -c 'sort_by(-.saved)' ;;
delete)
    rm -f -- "$DIR/$(name "${2:-}").json" ;;
*)
    sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
