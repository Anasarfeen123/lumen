#!/bin/sh
# system-info.sh — one snapshot of system load as key=value lines.
# Called by the shell every 2 s ONLY while the control centre is open.
# Cheap by design: reads /proc and /sys, never wakes the NVIDIA dGPU
# (no nvidia-smi — its runtime PM status is read from sysfs instead).
#
#   cpu=<user nice system idle iowait irq softirq steal>   (jiffies, from /proc/stat)
#   mem_total_kb= / mem_available_kb=
#   cpu_temp_mc=     millidegrees (k10temp Tctl, or first coretemp)
#   igpu_busy=       0–100 (AMD iGPU)
#   dgpu=            active | suspended | absent
#   disk_used_pct=   root filesystem
set -u

# shellcheck disable=SC2046  # split /proc/stat fields on purpose
set -- $(head -1 /proc/stat)
shift
echo "cpu=$1 $2 $3 $4 $5 $6 $7 $8"

awk '/^MemTotal:/ {print "mem_total_kb=" $2} /^MemAvailable:/ {print "mem_available_kb=" $2}' /proc/meminfo

for h in /sys/class/hwmon/hwmon*; do
    case $(cat "$h/name" 2>/dev/null) in
        k10temp|coretemp) echo "cpu_temp_mc=$(cat "$h/temp1_input" 2>/dev/null || echo 0)"; break ;;
    esac
done

dgpu=absent
for dev in /sys/class/drm/card[0-9]*; do
    case $dev in *-*) continue ;; esac
    case $(cat "$dev/device/vendor" 2>/dev/null) in
        0x1002) echo "igpu_busy=$(cat "$dev/device/gpu_busy_percent" 2>/dev/null || echo 0)" ;;
        0x10de) dgpu=$(cat "$dev/device/power/runtime_status" 2>/dev/null || echo unknown) ;;
    esac
done
echo "dgpu=$dgpu"

df -P / | awk 'NR==2 {sub("%", "", $5); print "disk_used_pct=" $5}'
