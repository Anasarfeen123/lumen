#!/bin/sh
# connect.sh — Lumen Connect: your phone through KDE Connect (kdeconnectd).
#   connect.sh status                    JSON: [{id,name,type,paired,reachable,battery,charging}]
#   connect.sh ring|ping|send-clipboard|pair|unpair <id>
#   connect.sh share <id> <file-or-url>  ·  connect.sh pick-and-share <id>
#   connect.sh refresh                   look for devices on the network
# Everything goes through kdeconnect-cli / the daemon's D-Bus; no network
# code of its own.
set -u
command -v kdeconnect-cli >/dev/null || { [ "${1:-}" = status ] && echo '{"available":false,"devices":[]}'; exit 0; }
prop() { busctl --user get-property org.kde.kdeconnect "/modules/kdeconnect/devices/$1$2" "$3" "$4" 2>/dev/null | awk '{print $2}' | tr -d '"'; }
case ${1:-} in
status)
    all=$(kdeconnect-cli -l --id-name-only 2>/dev/null)
    up=$(kdeconnect-cli -a --id-only 2>/dev/null)
    printf '%s\n' "$all" | while IFS= read -r line; do
        [ -n "$line" ] || continue
        id=${line%% *}; name=${line#* }
        reach=false; printf '%s\n' "$up" | grep -qx "$id" && reach=true
        paired=$(prop "$id" "" org.kde.kdeconnect.device isPaired); [ "$paired" = true ] || paired=false
        type=$(prop "$id" "" org.kde.kdeconnect.device type)
        bat=$(prop "$id" /battery org.kde.kdeconnect.device.battery charge); chg=$(prop "$id" /battery org.kde.kdeconnect.device.battery isCharging)
        jq -n -c --arg id "$id" --arg name "$name" --arg type "${type:-phone}" --argjson paired "$paired" --argjson reach "$reach" \
            --argjson bat "${bat:--1}" --arg chg "${chg:-false}" \
            '{id: $id, name: $name, type: $type, paired: $paired, reachable: $reach, battery: $bat, charging: ($chg == "true")}'
    done | jq -s -c '{available: true, devices: .}' ;;
ring|ping|send-clipboard|pair|unpair)
    exec kdeconnect-cli -d "${2:?device id}" "--$1" ;;
share)
    exec kdeconnect-cli -d "${2:?device id}" --share "${3:?file or url}" ;;
pick-and-share)
    f=$(kdialog --title "Send to your phone" --getopenfilename "$HOME" 2>/dev/null || zenity --file-selection --title "Send to your phone" 2>/dev/null) || exit 0
    exec kdeconnect-cli -d "${2:?device id}" --share "$f" ;;
refresh)
    exec kdeconnect-cli --refresh ;;
*)
    sed -n '3,7p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
