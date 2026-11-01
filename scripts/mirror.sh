#!/bin/sh
# mirror.sh — a small mirror from the webcam, to check yourself before a call.
#   mirror.sh [toggle]    open it (bottom-right, pinned, mirrored); again: close it
# ffplay draws it; hypr/rules.lua floats and pins the "Lumen mirror" window.
# Nothing is recorded or saved. The camera light shows while it's open.
set -eu
PIDFILE=${XDG_RUNTIME_DIR:-/tmp}/lumen-mirror.pid
if [ -s "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
    kill "$(cat "$PIDFILE")"; rm -f "$PIDFILE"; exit 0
fi
dev=""
for d in /dev/video*; do [ -c "$d" ] && { dev=$d; break; }; done
[ -n "$dev" ] || { notify-send -a Lumen "No camera found" ""; exit 1; }
ffplay -loglevel error -f v4l2 -video_size 640x480 -i "$dev" -vf hflip \
       -window_title "Lumen mirror" -noborder -x 384 -y 288 -an &
echo $! > "$PIDFILE"
