#!/bin/sh
# power-admin.sh — battery charge limit, set by Lumen Settings through pkexec
# (polkit asks for your admin password every time).
#
#   power-admin.sh charge-limit <60–100>
#
# Stopping at 80 % keeps a laptop that lives on its charger healthy for
# longer. The limit is written to the battery now AND to
# /etc/tmpfiles.d/lumen-battery.conf so it is re-applied at every boot
# (the firmware forgets it on power-off). 100 removes the boot file.
set -eu

[ "$(id -u)" = 0 ] || { echo "power-admin.sh: must run as root (via pkexec)" >&2; exit 1; }

bat=""
for b in /sys/class/power_supply/BAT*; do
    [ -w "$b/charge_control_end_threshold" ] && { bat=$b; break; }
done
[ -n "$bat" ] || { echo "power-admin.sh: this battery has no charge limit control" >&2; exit 1; }

case ${1:-} in
    charge-limit)
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
    *)
        echo "usage: power-admin.sh charge-limit <60-100>" >&2; exit 2 ;;
esac
