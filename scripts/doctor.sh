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
