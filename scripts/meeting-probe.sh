#!/bin/sh
# meeting-probe.sh — who is using the microphone or the camera right now.
# Read-only: asks PipeWire (through pactl) and reads /proc.
#   meeting-probe.sh mic       JSON: [{app, bin, pid}] recording from a real input
#                              (captures of a speaker's ".monitor" — visualizers,
#                              screen recorders' system sound — don't count)
#   meeting-probe.sh camera    JSON: [{app, pid}] with a /dev/video* device open
set -u

case ${1:-} in
mic)
    command -v pactl >/dev/null || { echo '[]'; exit 0; }
    sources=$(pactl -f json list sources 2>/dev/null) || { echo '[]'; exit 0; }
    pactl -f json list source-outputs 2>/dev/null | jq -c --argjson s "${sources:-[]}" '
        ($s | map({key: (.index | tostring), value: .name}) | from_entries) as $name
        | [ .[]
            | select((.corked // false) | not)
            | select(($name[(.source | tostring)] // "") | endswith(".monitor") | not)
            | { app: (.properties["application.name"] // .properties["application.process.binary"] // "An app"),
                bin: (.properties["application.process.binary"] // ""),
                pid: ((.properties["application.process.id"] // "0") | tonumber? // 0) } ]
        | unique_by(.bin + .app)' 2>/dev/null || echo '[]' ;;
camera)
    # Only your own processes are readable; find does the fd walk in one go
    find /proc/[0-9]*/fd -maxdepth 1 -lname '/dev/video*' -printf '%h\n' 2>/dev/null | sort -u |
        while IFS= read -r d; do
            p=${d%/fd}
            printf '%s\t%s\n' "${p#/proc/}" "$(cat "$p/comm" 2>/dev/null)"
        done | jq -R -s -c '
            [ split("\n")[] | select(length > 0) | split("\t") | {pid: (.[0] | tonumber), app: .[1]}
              | select(.app | test("^(pipewire|wireplumber|v4l2|gst-plugin-scan)") | not) ]' ;;
*)
    sed -n '2,7p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
