#!/bin/sh
# doctor.sh — Settings → Advanced. Read-only, except where a mode says so.
#   doctor.sh check              health check as JSON: [{title, detail, state: ok|warn|error}]
#   doctor.sh version            the Lumen version (git describe)
#   doctor.sh open <path>        open a file in your editor (a folder in the file manager)
#   doctor.sh reveal <path>      show a file in the file manager
#   doctor.sh shell-log <out>    copy this session's shell log to <out>
#   doctor.sh journal <out>      copy the last 300 lines of your user journal (this boot) to <out>
#   doctor.sh create local.lua|session.env   WRITES: a commented template, never over an existing file
#   doctor.sh reset shell|state  WRITES: moves shell.json / state.json aside as .bak-<date> (never deletes)
set -u
LUMEN_ROOT=${LUMEN_ROOT:-$HOME/.config/lumen}
STATE_DIR=${XDG_STATE_HOME:-$HOME/.local/state}/lumen

item() { jq -cn --arg t "$1" --arg d "$2" --arg s "$3" '{title:$t, detail:$d, state:$s}'; }

case ${1:-} in
check)
    {
        # Hyprland config (this session only)
        if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]; then
            errs=$(hyprctl configerrors 2>/dev/null | grep -v '^\s*$')
            if [ -z "$errs" ]; then item "Hyprland config" "No errors" ok
            else item "Hyprland config" "$(printf '%s' "$errs" | head -n 3 | tr '\n' ' ')" error; fi
        else
            item "Hyprland config" "Not running inside Hyprland" warn
        fi
        # Theme contrast
        fails=$(python3 "$LUMEN_ROOT/theme/build.py" --check 2>/dev/null | jq -r '.failures | length' 2>/dev/null || echo "?")
        case $fails in
            0) item "Theme contrast" "Every text colour meets its contrast target" ok ;;
            \?) item "Theme contrast" "Couldn't run theme/build.py --check" error ;;
            *) item "Theme contrast" "$fails colour pair(s) below target — lumen check shows which" warn ;;
        esac
        # The install link (the "~" in these messages is display text)
        link=$(readlink -f "$HOME/.config/lumen" 2>/dev/null)
        # shellcheck disable=SC2088
        if [ -n "$link" ] && [ -f "$link/hypr/hyprland.lua" ]; then item "Install link" "~/.config/lumen → ${link#"$HOME"/}" ok
        else item "Install link" "~/.config/lumen is missing or points somewhere unexpected — run ./install.sh" error; fi
        if [ -f "$LUMEN_ROOT/generated/tokens.json" ]; then item "Generated theme" "Present" ok
        else item "Generated theme" "Missing — press Rebuild theme" error; fi
        # Programs
        missing=""
        for c in Hyprland qs jq wl-copy wl-paste cliphist grim slurp hyprctl; do command -v "$c" >/dev/null 2>&1 || missing="$missing $c"; done
        if [ -z "$missing" ]; then item "Required programs" "All installed" ok
        else item "Required programs" "Missing:$missing — ./install.sh installs them" error; fi
        opt=""
        for c in hypridle hyprpicker udisksctl nmcli qt6ct tesseract swappy wf-recorder kdeconnect-cli ollama; do command -v "$c" >/dev/null 2>&1 || opt="$opt $c"; done
        if [ -z "$opt" ]; then item "Optional programs" "All installed" ok
        else item "Optional programs" "Not installed:$opt — the features that use them stay hidden" warn; fi
        # Hyprland crashes in the last 14 days (~/.cache/hyprland), and what they share
        crashdir=${XDG_CACHE_HOME:-$HOME/.cache}/hyprland
        recent=$(find "$crashdir" -maxdepth 1 -name 'hyprlandCrashReport*.txt' -mtime -14 2>/dev/null)
        if [ -z "$recent" ]; then item "Hyprland crashes" "None in the last 14 days" ok
        else
            n=$(printf '%s\n' "$recent" | wc -l)
            fence=$(printf '%s\n' "$recent" | xargs grep -l eglDupNativeFenceFDANDROID 2>/dev/null | wc -l)
            last=$(printf '%s\n' "$recent" | xargs ls -t | head -1)
            when=$(date -r "$last" '+%-d %b %H:%M')
            if [ "$fence" -gt 0 ]; then
                item "Hyprland crashes" "$n in 14 days (last $when); $fence after a multi-GPU fence error — log out and back in so the AQ_MGPU_NO_EXPLICIT fix applies" error
            else
                item "Hyprland crashes" "$n in 14 days (last $when) — ${last##*/} has the backtrace" warn
            fi
        fi
        # The shell's most repeated warning this session (one noisy source drowns the rest)
        tmp=$(mktemp)
        "$0" shell-log "$tmp" >/dev/null 2>&1
        top=$(grep -E ' WARN | ERROR ' "$tmp" | sed -E 's/0x[0-9a-f]+|id=[0-9]+|[0-9]+/N/g' | sort | uniq -c | sort -rn | head -1)
        rm -f "$tmp"
        count=$(printf '%s' "$top" | awk '{print $1}')
        what=$(printf '%s' "$top" | sed -E 's/^ *[0-9]+ +//; s/^ *(WARN|ERROR) *//' | cut -c1-110)
        if [ -z "$top" ]; then item "Shell log" "No warnings this session" ok
        elif [ "${count:-0}" -ge 100 ]; then item "Shell log" "${count}× $what" warn
        else item "Shell log" "Quiet — the most repeated warning appears ${count}×" ok; fi
        # Lumen's own user services (and the AmazeCC API, if you run it)
        failed=$(systemctl --user list-units --failed --plain --no-legend 2>/dev/null | awk '{print $1}' | grep -E '^(lumen|amazecc)' | tr '\n' ' ')
        if [ -z "$failed" ]; then item "Lumen services" "None failed" ok
        else item "Lumen services" "Failed: $failed— systemctl --user status shows why" error; fi
        # Local AI
        if curl -fsS --max-time 1 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
            n=$(curl -fsS --max-time 2 http://127.0.0.1:11434/api/tags | jq '.models | length')
            item "Local AI (Ollama)" "Running · $n model(s)" ok
        else
            item "Local AI (Ollama)" "Not running — Lumen Halo can use Claude instead, or start ollama" warn
        fi
    } | jq -sc . ;;
version)
    git -C "$LUMEN_ROOT" describe --always --dirty --tags 2>/dev/null || echo unknown ;;
open)
    p=${2:?}
    if [ -d "$p" ]; then exec xdg-open "$p"; fi
    [ -e "$p" ] || exit 1
    exec "$LUMEN_ROOT/bin/lumen-launch" "code $p" "codium $p" "zed $p" "kate $p" "xdg-open $p" ;;
reveal)
    p=${2:?}
    exec dbus-send --session --type=method_call --dest=org.freedesktop.FileManager1 /org/freedesktop/FileManager1 \
        org.freedesktop.FileManager1.ShowItems array:string:"file://$p" string:"" ;;
shell-log)
    out=${2:?}
    umask 077
    pid=""
    for p in $(pgrep -u "$(id -u)" -x qs); do
        tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | grep -qx "HYPRLAND_INSTANCE_SIGNATURE=${HYPRLAND_INSTANCE_SIGNATURE:-}" || continue
        tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q 'lumen/shell' && { pid=$p; break; }
    done
    if [ -n "$pid" ]; then qs log --pid "$pid" 2>&1 | sed 's/\x1b\[[0-9;]*m//g' > "$out"
    else echo "No Lumen shell found in this session." > "$out"; fi ;;
journal)
    out=${2:?}
    umask 077
    journalctl --user -b -n 300 --no-pager > "$out" 2>&1 ;;
create)
    case ${2:-} in
    local.lua)
        f=$LUMEN_ROOT/local.lua
        [ -e "$f" ] && { echo exists; exit 0; }
        cat > "$f" <<'EOF'
-- local.lua — your own Hyprland additions, loaded last (not tracked by git).
-- Plain Hyprland Lua. Examples (remove the leading "--" to use one):
--
-- hl.monitor({ output = "HDMI-A-1", mode = "2560x1440@144", position = "auto-right", scale = 1 })
-- hl.config({ input = { kb_layout = "us,de", kb_options = "grp:alt_shift_toggle" } })
-- hl.bind("SUPER + B", hl.dsp.exec_cmd("firefox"), { description = "Apps: Firefox" })
EOF
        echo created ;;
    session.env)
        f=$LUMEN_ROOT/session.env
        [ -e "$f" ] && { echo exists; exit 0; }
        cat > "$f" <<'EOF'
# session.env — environment for the Lumen session (not tracked by git).
# Read at login by bin/lumen-session. One VAR=value per line.
#
# Leave an NVIDIA GPU completely alone (battery life):
# LUMEN_DGPU=off
EOF
        echo created ;;
    *) echo "usage: doctor.sh create local.lua|session.env" >&2; exit 2 ;;
    esac ;;
reset)
    case ${2:-} in shell|state) ;; *) echo "usage: doctor.sh reset shell|state" >&2; exit 2 ;; esac
    f=$STATE_DIR/$2.json
    [ -e "$f" ] || { echo nothing; exit 0; }
    mv -- "$f" "$f.bak-$(date +%Y%m%d-%H%M%S)" && echo moved ;;
*)
    sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
