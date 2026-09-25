#!/bin/sh
# gaze-admin.sh — the ONLY things Lumen Settings changes as root, each behind
# your admin password (Settings runs it through pkexec; polkit asks every time).
#
#   gaze-admin.sh liveness on|off          anti-photo check  ([liveness] enabled)
#   gaze-admin.sh threshold 0.05–0.95      its strictness     ([liveness] threshold)
#   gaze-admin.sh debug on|off             per-frame scores in the gazed log
#
# Every argument is validated; it touches only /etc/gaze/config.toml's
# [liveness] section and one systemd drop-in, keeps a one-time backup of the
# original config (config.toml.lumen.bak), then restarts gazed.
set -eu

CONF=/etc/gaze/config.toml
DROPIN=/etc/systemd/system/gazed.service.d/lumen-debug.conf

[ "$(id -u)" = 0 ] || { echo "gaze-admin.sh: must run as root (via pkexec)" >&2; exit 1; }
[ -w "$CONF" ] || { echo "gaze-admin.sh: $CONF not found" >&2; exit 1; }

usage() { sed -n '4,6p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }

set_liveness() {   # set_liveness <key> <value>   (only inside [liveness])
    [ -e "$CONF.lumen.bak" ] || cp -p "$CONF" "$CONF.lumen.bak"
    sed -i "/^\[liveness\]/,/^\[/{s/^$1 = .*/$1 = $2/}" "$CONF"
    grep -q "^$1 = $2\$" "$CONF" || { echo "gaze-admin.sh: could not set $1" >&2; exit 1; }
}

case ${1:-} in
    liveness)
        case ${2:-} in on) set_liveness enabled true ;; off) set_liveness enabled false ;; *) usage ;; esac ;;
    threshold)
        v=${2:-}
        printf '%s' "$v" | grep -Eq '^0\.[0-9]{1,2}$' || usage
        awk -v v="$v" 'BEGIN { exit !(v >= 0.05 && v <= 0.95) }' || usage
        set_liveness threshold "$v" ;;
    debug)
        case ${2:-} in
            on)  mkdir -p "${DROPIN%/*}"; printf '[Service]\nEnvironment=RUST_LOG=debug\n' > "$DROPIN" ;;
            off) rm -f "$DROPIN" /etc/systemd/system/gazed.service.d/debug.conf ;;
            *)   usage ;;
        esac
        systemctl daemon-reload ;;
    *)
        usage ;;
esac

systemctl restart gazed
