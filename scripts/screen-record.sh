#!/bin/sh
# screen-record.sh — start/stop screen recording; the island shows it live.
#   screen-record.sh toggle [region|screen] [--audio]
#   screen-record.sh pause       pause, or resume (the island: right-click)
#   screen-record.sh stop
# Pausing closes the current segment; resuming records the same area into the
# next one; stopping joins them (ffmpeg, no re-encode) into the one file.
# Saves to $XDG_VIDEOS_DIR/Recordings. Encodes AV1 on the AMD iGPU (VAAPI) so
# recording doesn't load the CPU or wake the NVIDIA dGPU. (Fedora's Mesa has
# no H.264/HEVC hardware encoding — patents; AV1 is available.) Falls back to
# wf-recorder's default software encoder if VAAPI AV1 isn't usable.
set -eu

LUMEN_ROOT=${LUMEN_ROOT:-$HOME/.config/lumen}
PIDFILE=${XDG_RUNTIME_DIR:-/tmp}/lumen-record.pid
FILEREC=${XDG_RUNTIME_DIR:-/tmp}/lumen-record.path
TARGETREC=${XDG_RUNTIME_DIR:-/tmp}/lumen-record.target     # flag, target, audio — to resume the same area
PARTS=${XDG_RUNTIME_DIR:-/tmp}/lumen-record.parts          # segment files, in order
PAUSED=${XDG_RUNTIME_DIR:-/tmp}/lumen-record.paused

island() { "$LUMEN_ROOT/bin/lumen-shell-ipc" island "$@" >/dev/null 2>&1 || true; }

running() { [ -s "$PIDFILE" ] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; }

# end the current segment: SIGINT, and wait for the file to be finalised (max ~5 s)
finish_segment() {
    running || return 0
    kill -INT "$(cat "$PIDFILE")"
    i=0; while running && [ $i -lt 50 ]; do sleep 0.1; i=$((i + 1)); done
    rm -f "$PIDFILE"
}

stop() {
    if ! running && [ ! -e "$PAUSED" ]; then island recording false; return 0; fi
    finish_segment
    file=$(cat "$FILEREC" 2>/dev/null || echo "")
    # several segments (it was paused): join them, no re-encode
    if [ -n "$file" ] && [ "$(wc -l < "$PARTS" 2>/dev/null || echo 0)" -gt 1 ]; then
        list=$(mktemp)
        while IFS= read -r part; do [ -s "$part" ] && printf "file '%s'\n" "$part"; done < "$PARTS" > "$list"
        if ffmpeg -loglevel error -y -f concat -safe 0 -i "$list" -c copy "$file.joined.mp4"; then
            while IFS= read -r part; do rm -f "$part"; done < "$PARTS"
            mv "$file.joined.mp4" "$file"
        fi
        rm -f "$list"
    fi
    rm -f "$PAUSED" "$PARTS" "$TARGETREC"
    island recordingSaved "${file:-recording}"
}

pause() {
    if [ -e "$PAUSED" ]; then
        # resume: the same area, into the next segment
        file=$(cat "$FILEREC")
        IFS='|' read -r TARGET_FLAG TARGET AUDIO < "$TARGETREC"
        part="${file%.mp4}.part$(($(wc -l < "$PARTS") + 1)).mp4"
        echo "$part" >> "$PARTS"
        if dev=$(amd_render) && launch "$part" -c av1_vaapi -d "$dev" || launch "$part"; then
            rm -f "$PAUSED"; island recordingPaused false
        else
            island event error "Couldn't resume recording" "wf-recorder exited"
        fi
    elif running; then
        finish_segment
        : > "$PAUSED"
        island recordingPaused true
    fi
}

# First render node whose PCI vendor is AMD (0x1002)
amd_render() {
    for n in /sys/class/drm/renderD*; do
        [ "$(cat "$n/device/vendor" 2>/dev/null)" = 0x1002 ] && { echo "/dev/dri/${n##*/}"; return 0; }
    done
    return 1
}

# launch <file> <encoder-args…> — the target (-g/-o) comes from $TARGET_FLAG/$TARGET
launch() {
    out=$1; shift
    if [ -n "$AUDIO" ]; then
        wf-recorder "$TARGET_FLAG" "$TARGET" --audio "$@" -f "$out" >/dev/null 2>&1 &
    else
        wf-recorder "$TARGET_FLAG" "$TARGET" "$@" -f "$out" >/dev/null 2>&1 &
    fi
    echo $! > "$PIDFILE"
    sleep 0.4
    running
}

start() {
    mode=${1:-screen}
    AUDIO=; [ "${2:-}" = --audio ] && AUDIO=1
    vids=$(xdg-user-dir VIDEOS 2>/dev/null || echo "$HOME/Videos")
    dir="$vids/Recordings"; mkdir -p "$dir"
    file="$dir/$(date +%Y-%m-%d_%H-%M-%S).mp4"

    case $mode in
        region) TARGET_FLAG=-g; TARGET=$(slurp -d) || exit 0 ;;
        screen) TARGET_FLAG=-o; TARGET=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name') ;;
        *) echo "usage: screen-record.sh toggle [region|screen] [--audio]" >&2; exit 2 ;;
    esac

    printf '%s\n' "$file" > "$FILEREC"
    printf '%s\n' "$file" > "$PARTS"
    printf '%s|%s|%s\n' "$TARGET_FLAG" "$TARGET" "$AUDIO" > "$TARGETREC"
    rm -f "$PAUSED"
    if dev=$(amd_render) && launch "$file" -c av1_vaapi -d "$dev"; then
        island recording true
    elif launch "$file"; then          # software fallback
        island recording true
    else
        rm -f "$PIDFILE"; island event error "Recording failed" "wf-recorder exited"; exit 1
    fi
}

case ${1:-} in
    toggle) if running || [ -e "$PAUSED" ]; then stop; else start "${2:-screen}" "${3:-}"; fi ;;
    pause)  pause ;;
    stop)   stop ;;
    *)      sed -n '2,6p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
