#!/bin/sh
# shell-supervisor.sh — runs the Lumen shell and brings it back if it crashes.
#   shell-supervisor.sh <shell dir>
# A crash = the shell exits with a non-zero status while this Hyprland session
# is still running (logging out ends Hyprland first, so that's never a crash).
# It restarts with a growing pause (1, 2, 4… s) and gives up after 5 crashes in
# 5 minutes, saying so — something is broken and a loop would only hide it.
# After a restart it leaves $XDG_RUNTIME_DIR/lumen-shell-restarted for the shell
# to read and announce in the island (modules/island/IslandSources.qml).
set -u
dir=${1:?usage: shell-supervisor.sh <shell dir>}
note=${XDG_RUNTIME_DIR:-/tmp}/lumen-shell-restarted
crashes=""          # epoch seconds of recent crashes
pause=1

alive() { hyprctl -j version >/dev/null 2>&1; }

while :; do
    qs -p "$dir"
    status=$?
    [ "$status" -eq 0 ] && exit 0            # asked to quit
    alive || exit 0                          # the session ended under it
    now=$(date +%s)
    crashes=$(for t in $crashes $now; do [ $((now - t)) -lt 300 ] && echo "$t"; done)
    n=$(printf '%s\n' "$crashes" | grep -c .)
    echo "shell-supervisor: the shell exited with status $status ($n in 5 min)" >&2
    if [ "$n" -ge 5 ]; then
        notify-send -u critical -a Lumen "Lumen's shell keeps crashing" \
            "It stopped $n times in 5 minutes, so it won't be restarted again. Super+Enter opens a terminal; lumen doctor shows what's wrong." 2>/dev/null
        exit 1
    fi
    printf '%s %s\n' "$now" "$status" > "$note"
    sleep "$pause"
    pause=$((pause * 2))
done
