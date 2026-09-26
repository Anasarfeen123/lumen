#!/bin/sh
# inspect.sh — hardware and system facts for Settings → System, as JSON.
# Read-only, no root. Fast values (CPU %, temperatures) come from
# services/Sysinfo; this gives the slower-changing details.
set -u
cpu_model=$(lscpu | sed -n 's/^Model name: *//p' | head -1)
threads=$(nproc)
cores=$(lscpu -p=CORE 2>/dev/null | grep -v '^#' | sort -u | wc -l)
maxmhz=$(lscpu | sed -n 's/^CPU max MHz: *//p' | cut -d. -f1)
curmhz=$(awk '/cpu MHz/ {s+=$4; n++} END {if (n) printf "%d", s/n}' /proc/cpuinfo)
kernel=$(uname -r); host=$(hostname)
os=$(. /etc/os-release; echo "${PRETTY_NAME:-Linux}")
uptime_s=$(cut -d. -f1 /proc/uptime)
hypr=$(Hyprland --version 2>/dev/null | head -1 | awk '{print $2}')
qsv=$(qs --version 2>/dev/null | awk '{print $2}')
swap_total=$(awk '/SwapTotal/ {print $2}' /proc/meminfo); swap_free=$(awk '/SwapFree/ {print $2}' /proc/meminfo)

# GPUs: every DRM card with its vendor; AMD busy/VRAM/temp from sysfs
gpus="[]"
for c in /sys/class/drm/card[0-9]; do
    [ -e "$c/device/vendor" ] || continue
    v=$(cat "$c/device/vendor"); name=$(lspci -s "$(basename "$(readlink -f "$c/device")")" 2>/dev/null | sed 's/^[^:]*: *//; s/^[^:]*: //')
    busy=$(cat "$c/device/gpu_busy_percent" 2>/dev/null || echo -1)
    vu=$(cat "$c/device/mem_info_vram_used" 2>/dev/null || echo -1); vt=$(cat "$c/device/mem_info_vram_total" 2>/dev/null || echo -1)
    t=$(cat "$c"/device/hwmon/hwmon*/temp1_input 2>/dev/null | head -1); t=${t:--1000}
    rs=$(cat "$c/device/power/runtime_status" 2>/dev/null || echo unknown)
    gpus=$(printf '%s' "$gpus" | jq -c --arg card "${c##*/}" --arg v "$v" --arg name "$name" --argjson busy "${busy:--1}" \
        --argjson vu "$vu" --argjson vt "$vt" --argjson t "$t" --arg rs "$rs" \
        '. + [{card: $card, vendor: $v, name: $name, busy: $busy, vramUsed: $vu, vramTotal: $vt, temp: ($t / 1000), state: $rs}]')
done

disks=$(df -B1 --output=source,fstype,size,used,target -x tmpfs -x devtmpfs -x efivarfs -x overlay -x squashfs 2>/dev/null | tail -n +2 |
        awk '!seen[$1 $5]++' | jq -R -s -c '[split("\n")[] | select(length > 0) | split(" ") | map(select(length > 0)) |
            {source: .[0], fs: .[1], size: (.[2]|tonumber), used: (.[3]|tonumber), mount: .[4]}]')

jq -n -c --arg cpu "$cpu_model" --argjson threads "$threads" --argjson cores "$cores" --argjson maxmhz "${maxmhz:-0}" --argjson curmhz "${curmhz:-0}" \
    --arg kernel "$kernel" --arg host "$host" --arg os "$os" --argjson uptime "$uptime_s" --arg hypr "$hypr" --arg qs "$qsv" \
    --argjson swapTotal "${swap_total:-0}" --argjson swapFree "${swap_free:-0}" --argjson gpus "$gpus" --argjson disks "$disks" \
    '{cpu: {model: $cpu, threads: $threads, cores: $cores, maxMhz: $maxmhz, curMhz: $curmhz},
      system: {kernel: $kernel, host: $host, os: $os, uptime: $uptime, hyprland: $hypr, quickshell: $qs},
      swap: {total: ($swapTotal * 1024), used: (($swapTotal - $swapFree) * 1024)}, gpus: $gpus, disks: $disks}'
