#!/bin/sh
# bench.sh — what the shell costs, in a form you can compare over time.
#
#   bench.sh                 the running shell, as text
#   bench.sh --json          the same numbers, as JSON (for diffing runs)
#   bench.sh --cpu 10        idle CPU over 10 s instead of 5
#
# Three numbers matter, and they are not the same number:
#
#   RSS      every page mapped into the process, including the icon and
#            font files it shares with every other Qt app on the machine
#   PSS      RSS divided by the number of processes sharing each page —
#            the honest "what did this cost the system" figure
#   Pss_Anon RSS minus shared files: memory the shell actually allocated
#
# A big RSS with a small Pss_Anon is a font cache, not a leak. Reading
# only RSS makes a healthy shell look like a hungry one, so all three are
# always reported together.
#
# Read-only: /proc is read, nothing is written, nothing is signalled.
set -u

CPU_SECS=5
JSON=0
while [ $# -gt 0 ]; do
    case $1 in
        --json) JSON=1; shift ;;
        --cpu) CPU_SECS=${2:?usage: bench.sh --cpu <seconds>}; shift 2 ;;
        -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "bench.sh: unknown option $1" >&2; exit 2 ;;
    esac
done

# ── Which process is the shell? ───────────────────────────────────────────
# The one whose argv is `qs -p <LUMEN_ROOT>/shell`, in THIS Hyprland
# session. A nested test session runs its own shell, and measuring that
# by accident would report the wrong desktop entirely, so nested shells
# are only used when there is nothing else to measure.
shell_pid() {
    sig=${HYPRLAND_INSTANCE_SIGNATURE:-}
    fallback=""
    for p in $(pgrep -u "$(id -u)" -x 'qs|quickshell' 2>/dev/null); do
        tr '\0' '\n' < "/proc/$p/cmdline" 2>/dev/null | grep -qx -- "-p" || continue
        if [ -n "$sig" ]; then
            tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null \
                | grep -qx "HYPRLAND_INSTANCE_SIGNATURE=$sig" || continue
        fi
        if tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | grep -qx "LUMEN_NESTED=1"; then
            [ -n "$fallback" ] || fallback=$p
            continue
        fi
        echo "$p"; return 0
    done
    # only nested test shells: measure one rather than refuse, but the report
    # says so (NESTED is set below)
    [ -n "$fallback" ] && { echo "$fallback"; return 0; }
    return 1
}

PID=$(shell_pid) || {
    msg="No Lumen shell found in this session (looking for qs -p .../shell)."
    [ "$JSON" = 1 ] && jq -cn --arg e "$msg" '{error:$e}' || echo "$msg"
    exit 1
}

# ── Memory ────────────────────────────────────────────────────────────────
# smaps_rollup gives every figure in one read. status is the fallback for
# kernels older than 4.5, which have no Pss_Anon: there, the closest honest
# answer is RssAnon (all of it private, none pro-rated), and it is labelled
# as such rather than passed off as a PSS.
rollup() { grep -E "^$1:" "/proc/$PID/smaps_rollup" 2>/dev/null | awk '{print $2}' | head -1; }
status_kb() { awk "/^$1:/ {print \$2}" "/proc/$PID/status" 2>/dev/null | head -1; }
num() { case ${1:-} in ''|*[!0-9]*) echo 0 ;; *) echo "$1" ;; esac; }
# first of two sources that actually produced a number
pick() { for v in "$@"; do [ -n "$v" ] && { echo "$v"; return; }; done; echo 0; }

RSS=$(num "$(pick "$(rollup Rss)" "$(status_kb VmRSS)")")
PSS=$(num "$(pick "$(rollup Pss)" "$(status_kb RssAnon)")")
ANON=$(num "$(pick "$(rollup Pss_Anon)" "$(status_kb RssAnon)")")
THREADS=$(num "$(status_kb Threads)")

# ── What the mapped files actually are ────────────────────────────────────
# The claim worth testing is that most of RSS is fonts and icons that
# every Qt app shares, not the shell being greedy. smaps names each
# mapping, so the resident pages can be sorted into buckets and the
# claim checked instead of believed.
MAPS=$(awk '
    # A mapping header: addr perms off dev inode [pathname]
    /^[0-9a-f]+-[0-9a-f]+ / {
        path = ""
        for (i = 6; i <= NF; i++) path = path (i > 6 ? " " : "") $i
        if (path ~ /\.(ttf|otf|ttc|pfb)$/ || path ~ /\/fonts?\//)        cat = "fonts"
        else if (path ~ /\.(so|so\.[0-9]+)(\.|$)/)                       cat = "libraries"
        else if (path ~ /\/icons?\// || path ~ /\.(svg|png|jpeg|webp)$/) cat = "icons"
        else if (path == "")                                             cat = "anonymous"
        else if (path ~ /^\[/)                                           cat = "heap/stack"
        else                                                              cat = "other files"
        next
    }
    /^Rss:/ { rss[cat] += $2 }
    END { for (c in rss) printf "%s\t%d\n", c, rss[c] }
' "/proc/$PID/smaps" 2>/dev/null | sort -t"$(printf '\t')" -k2 -rn)

FONTS=$(printf '%s\n' "$MAPS" | awk -F'\t' '$1=="fonts"{s+=$2} END{print s+0}')
LIBS=$(printf '%s\n' "$MAPS" | awk -F'\t' '$1=="libraries"{s+=$2} END{print s+0}')
ICONS=$(printf '%s\n' "$MAPS" | awk -F'\t' '$1=="icons"{s+=$2} END{print s+0}')
OTHERF=$(printf '%s\n' "$MAPS" | awk -F'\t' '$1=="other files"{s+=$2} END{print s+0}')
HEAP=$(printf '%s\n' "$MAPS" | awk -F'\t' '$1=="heap/stack"{s+=$2} END{print s+0}')
# Raw RSS of the unmapped (anonymous) regions, so the buckets below add up to
# RSS. Deliberately not Pss_Anon, which is pro-rated and would not.
ANONMAPS=$(printf '%s\n' "$MAPS" | awk -F'\t' '$1=="anonymous"{s+=$2} END{print s+0}')

# ── Idle CPU ──────────────────────────────────────────────────────────────
# Sampled from /proc like peek-stats.sh: utime+stime in clock ticks,
# so no ps, no top, and the same units as everything else in Lumen.
ticks() { awk '{ n=split($0, a, " "); print a[14] + a[15] }' "/proc/$1/stat" 2>/dev/null; }
HZ=$(getconf CLK_TCK 2>/dev/null || echo 100)
CORES=$(nproc 2>/dev/null || echo 1)
T0=$(ticks "$PID"); sleep "$CPU_SECS"; T1=$(ticks "$PID")
CPU=$(awk -v d="$((T1 - T0))" -v hz="$HZ" -v s="$CPU_SECS" 'BEGIN{ printf "%.1f", (d/hz/s)*100 }')
# The same load as a share of the whole machine. Both are reported because
# "10% CPU" means two different things depending on which one you meant, and
# comparing a whole-system figure against a per-core figure invents a
# regression that is not there.
CPU_SYS=$(awk -v c="$CPU" -v n="$CORES" 'BEGIN{ printf "%.2f", c/n }')

# The island animates at the visualiser's frame rate while music plays, so a
# reading taken with music on is not comparable with one taken without.
VIZ=no
pgrep -P "$PID" -x cava >/dev/null 2>&1 && VIZ=yes
NESTED=no
tr '\0' '\n' < "/proc/$PID/environ" 2>/dev/null | grep -qx "LUMEN_NESTED=1" && NESTED=yes

# ── Startup ───────────────────────────────────────────────────────────────
# quickshell prints this once the QML tree is up. It is deliberately NOT
# presented as a duration: the log carries no timestamps, so the only honest
# thing to report is that the shell finished loading, and when the process
# itself started. A real launch-to-loaded figure needs a cold start in a test
# session (`lumen-session` nested), which would disturb a live desktop.
LOG=${XDG_RUNTIME_DIR:-/tmp}/lumen-startup.log
LOADED=no
grep -qa "Configuration Loaded" "$LOG" 2>/dev/null && LOADED=yes
UP=$(ps -o etimes= -p "$PID" 2>/dev/null | tr -d ' ')

# ── Report ────────────────────────────────────────────────────────────────
mb() { awk -v k="$1" 'BEGIN{ printf "%.0f", k/1024 }'; }
if [ "$JSON" = 1 ]; then
    buckets=$(printf '%s\n' "$MAPS" | jq -R 'split("\t") | {key:.[0], value:(.[1]|tonumber)}' \
        | jq -s 'from_entries' 2>/dev/null || echo '{}')
    jq -cn --argjson pid "$PID" \
        --argjson rss "$RSS" --argjson pss "$PSS" --argjson anon "$ANON" \
        --argjson threads "$THREADS" --argjson cpu "$CPU" --argjson cpusys "$CPU_SYS" \
        --argjson cores "$CORES" --argjson secs "$CPU_SECS" \
        --argjson fonts "$FONTS" --argjson libs "$LIBS" \
        --argjson icons "$ICONS" --argjson heap "$HEAP" --argjson other "$OTHERF" \
        --argjson up "${UP:-0}" --argjson loaded "$([ "$LOADED" = yes ] && echo true || echo false)" \
        --argjson buckets "$buckets" \
        --argjson visualiser "$([ "$VIZ" = yes ] && echo true || echo false)" \
        --argjson nested "$([ "$NESTED" = yes ] && echo true || echo false)" \
        '{pid:$pid, uptime_s:$up, loaded:$loaded, visualiser:$visualiser, nested:$nested,
          memory_kb:{rss:$rss, pss:$pss, pss_anon:$anon},
          mapped_kb:$buckets, threads:$threads,
          cpu:{percent_of_one_core:$cpu, percent_of_machine:$cpusys, cores:$cores, over_s:$secs}}'
    exit 0
fi

printf 'Lumen shell — pid %s, up %s\n' "$PID" "$( [ -n "${UP:-}" ] && printf '%dh%02dm' $((UP/3600)) $((UP%3600/60)) || echo '?' )"
[ "$NESTED" = yes ] && printf '  (this is a nested test session, not your login desktop)\n'
printf '\nMemory\n'
printf '  RSS        %4s MB   every mapped page (fonts and icons included)\n' "$(mb "$RSS")"
printf '  PSS        %4s MB   shared pages split between users — the fair cost\n' "$(mb "$PSS")"
printf '  Pss_Anon   %4s MB   memory the shell itself allocated\n' "$(mb "$ANON")"
printf '\nWhere the resident pages are (buckets of RSS)\n'
printf '  anonymous   %4s MB   the shell working\n' "$(mb "$ANONMAPS")"
printf '  fonts       %4s MB   shared with every other Qt app\n' "$(mb "$FONTS")"
printf '  libraries   %4s MB   shared with every other Qt app\n' "$(mb "$LIBS")"
printf '  icons       %4s MB   shared\n' "$(mb "$ICONS")"
printf '  other files %4s MB\n' "$(mb "$OTHERF")"
printf '  heap/stack  %4s MB\n' "$(mb "$HEAP")"
printf '\nIdle\n'
printf '  CPU         %4s%% of one core  =  %s%% of this %s-core machine (over %ss)\n' "$CPU" "$CPU_SYS" "$CORES" "$CPU_SECS"
[ "$VIZ" = yes ] && printf '               (music is playing: the island equaliser animates at 30 Hz)\n'
printf '  threads     %4s\n' "$THREADS"
printf '\nStartup\n'
printf '  shell up    %s, loaded: %s (the startup log has no timestamps, so no\n' \
    "$( [ -n "${UP:-}" ] && printf '%dh%02dm' $((UP/3600)) $((UP%3600/60)) || echo '?' )" \
    "$( [ "$LOADED" = yes ] && echo yes || echo "not in this login's log" )"
printf '              launch-to-loaded time; that needs a cold start in a test\n'
printf '              session, which would disturb a live desktop)\n'
exit 0
