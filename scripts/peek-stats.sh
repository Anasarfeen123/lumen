#!/bin/sh
# peek-stats.sh <pid>… — CPU and memory for each window's process tree, as JSON:
#   {"<pid>": {"cpu": <% of one core, over 0.5 s>, "mem": <MiB resident>}, …}
# Children count too (a browser's work happens in its child processes).
# Read-only: only /proc is read.
set -u
[ $# -gt 0 ] || { echo '{}'; exit 0; }

# All processes as "pid ppid ticks rss_pages"
snap() {
    for s in /proc/[0-9]*/stat; do
        # comm may contain spaces: strip "pid (comm) " first
        read -r line < "$s" 2>/dev/null || continue
        rest=${line##*) }
        pid=${s#/proc/}; pid=${pid%/stat}
        # shellcheck disable=SC2086
        set -- $rest
        # fields after comm: 1 state 2 ppid … 12 utime 13 stime … 22 rss
        printf '%s %s %s %s\n' "$pid" "$2" "$(( ${12} + ${13} ))" "${22}"
    done
}
a=$(snap); sleep 0.5; b=$(snap)
hz=$(getconf CLK_TCK 2>/dev/null || echo 100)
page=$(( $(getconf PAGESIZE 2>/dev/null || echo 4096) / 1024 ))
printf '%s\n--\n%s\n' "$a" "$b" | awk -v roots="$*" -v hz="$hz" -v page="$page" '
    $0 == "--" { second = 1; next }
    !second { t0[$1] = $3; next }
    { parent[$1] = $2; t1[$1] = $3; rss[$1] = $4 }
    END {
        n = split(roots, r, " ")
        printf "{"
        for (i = 1; i <= n; i++) {
            root = r[i]; cpu = 0; mem = 0
            for (p in t1) {
                q = p; hops = 0
                while (q != root && q > 1 && hops < 64) { q = parent[q]; hops++ }
                if (q == root) { cpu += (t1[p] - (p in t0 ? t0[p] : t1[p])); mem += rss[p] }
            }
            printf "%s\"%s\":{\"cpu\":%d,\"mem\":%d}", (i > 1 ? "," : ""), root, cpu * 100 / hz / 0.5, mem * page / 1024
        }
        print "}"
    }'
