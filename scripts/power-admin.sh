#!/bin/sh
# power-admin.sh — battery charge limit, and the NVIDIA GPU's power management,
# through pkexec (polkit asks for your admin password every time).
#
#   power-admin.sh charge-limit <60–100>
#   power-admin.sh dgpu-pm-reset      the NVIDIA GPU's runtime power management is
#                                     stuck ("error": it stays awake and drains the
#                                     battery) — switch it off and on again
#
# Stopping at 80 % keeps a laptop that lives on its charger healthy for
# longer. The limit is written to the battery now AND to
# /etc/tmpfiles.d/lumen-battery.conf so it is re-applied at every boot
# (the firmware forgets it on power-off). 100 removes the boot file.
set -eu

[ "$(id -u)" = 0 ] || { echo "power-admin.sh: must run as root (via pkexec)" >&2; exit 1; }

case ${1:-} in
    charge-limit)
        bat=""
        for b in /sys/class/power_supply/BAT*; do
            [ -w "$b/charge_control_end_threshold" ] && { bat=$b; break; }
        done
        [ -n "$bat" ] || { echo "power-admin.sh: this battery has no charge limit control" >&2; exit 1; }
        v=${2:-}
        case $v in ''|*[!0-9]*) echo "usage: power-admin.sh charge-limit <60-100>" >&2; exit 2 ;; esac
        [ "$v" -ge 60 ] && [ "$v" -le 100 ] || { echo "power-admin.sh: limit must be 60–100" >&2; exit 2; }
        printf '%s\n' "$v" > "$bat/charge_control_end_threshold"
        conf=/etc/tmpfiles.d/lumen-battery.conf
        if [ "$v" -eq 100 ]; then
            rm -f "$conf"
        else
            printf '# Lumen: battery charge limit (Lumen Settings → Power)\nw %s/charge_control_end_threshold - - - - %s\n' "$bat" "$v" > "$conf"
        fi ;;
    dgpu-pm-reset)
        # Every NVIDIA display controller (vendor 0x10de, class 0x03xxxx); no arguments taken
        n=0
        for d in /sys/bus/pci/devices/*; do
            [ "$(cat "$d/vendor" 2>/dev/null)" = 0x10de ] || continue
            case $(cat "$d/class" 2>/dev/null) in 0x03*) ;; *) continue ;; esac
            printf 'on\n' > "$d/power/control"
            sleep 1
            printf 'auto\n' > "$d/power/control"
            n=$((n + 1))
        done
        [ "$n" -gt 0 ] || { echo "power-admin.sh: no NVIDIA GPU" >&2; exit 1; } ;;
    *)
        echo "usage: power-admin.sh charge-limit <60-100> | dgpu-pm-reset" >&2; exit 2 ;;
esac
