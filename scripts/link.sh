#!/bin/sh
# link.sh — Lumen Link: your phone, through KDE Connect (kdeconnectd).
#   link.sh status                  JSON: {available, backends, custom, devices:[{id,name,type,paired,reachable,
#                                   battery,charging,via,signal}]}
#   link.sh doctor                  JSON: why the phone might not be found, and what would fix it
#   link.sh events                  follow the daemon: one JSON line per event (visible, battery, received)
#   link.sh ring|ping|send-clipboard|pair|unpair <id>
#   link.sh share <id> <file-or-url>…      send files or a link
#   link.sh text <id> <text>               send text (opens on the phone)
#   link.sh pick-and-share <id>            choose files, then send them
#   link.sh screenshot <id>                screenshot a region, send it
#   link.sh add-address <ip> | remove-address <ip>   find the phone by address (networks that hide devices)
#   link.sh backend lan|bluetooth on|off   KDE Connect's own link backends
#   link.sh refresh                         look for devices again
#   link.sh clip-sync <id> on|off|status   KDE Connect's clipboard plugin for that phone (shares both ways)
#   link.sh pan status                      JSON: the phone's Bluetooth network profile (NetworkManager PANU)
#   link.sh pan up                          bring it up (Bluetooth connect first); refuses unless it can never
#                                           become the default route, so the internet stays on Wi-Fi
#   link.sh pan safe                        set ipv4/ipv6.never-default on that profile (asks NetworkManager)
#   link.sh from-phone                      exit 0 if KDE Connect received data in the last 2.5 s
#                                           (tells a clipboard change that came from the phone apart)
# Everything goes through kdeconnect-cli / the daemon's D-Bus; no network
# code of its own. Nothing here needs root.
set -u
DEST=org.kde.kdeconnect
OBJ=/modules/kdeconnect
command -v kdeconnect-cli >/dev/null || {
    case ${1:-} in status) echo '{"available":false,"devices":[]}' ;; doctor) echo '{"installed":false}' ;; esac; exit 0; }
prop() { busctl --user get-property "$DEST" "$OBJ/devices/$1$2" "$3" "$4" 2>/dev/null | cut -d' ' -f2- | tr -d '"'; }
valid_ip() { printf '%s' "$1" | grep -Eqx '([0-9]{1,3}\.){3}[0-9]{1,3}|[0-9a-fA-F:]{2,39}'; }
custom() { busctl --user get-property "$DEST" "$OBJ" org.kde.kdeconnect.daemon customDevices 2>/dev/null | sed 's/^as [0-9]* *//' | tr -d '"'; }
set_custom() {   # set_custom ip…
    # shellcheck disable=SC2086
    busctl --user set-property "$DEST" "$OBJ" org.kde.kdeconnect.daemon customDevices as "$#" "$@"
}
# A USB network interface from a phone (USB tethering): rndis/cdc drivers or Apple's ipheth
tether_iface() {
    for n in /sys/class/net/*; do
        drv=$(basename "$(readlink "$n/device/driver" 2>/dev/null)" 2>/dev/null)
        case $drv in rndis_host|cdc_ncm|cdc_ether|ipheth) [ "$(cat "$n/operstate" 2>/dev/null)" != down ] && { basename "$n"; return 0; } ;; esac
    done
    return 1
}

# The phone's Bluetooth network (a NetworkManager "bluetooth" profile of type
# panu): a private link to the phone on networks that keep devices apart,
# while the internet stays on Wi-Fi (the profile must never be the default route).
pan_profile() { nmcli -t -f UUID,TYPE connection show 2>/dev/null | awk -F: '$2 == "bluetooth" { print $1; exit }'; }
pan_status() {
    uuid=$(pan_profile)
    [ -n "$uuid" ] || { echo '{"profile":""}'; return 0; }
    f=$(nmcli -g connection.id,bluetooth.bdaddr,bluetooth.type,ipv4.never-default,ipv6.never-default,GENERAL.STATE,GENERAL.DEVICES connection show "$uuid" 2>/dev/null)
    name=$(printf '%s\n' "$f" | sed -n 1p); mac=$(printf '%s\n' "$f" | sed -n 2p | tr -d '\\')
    kind=$(printf '%s\n' "$f" | sed -n 3p); v4=$(printf '%s\n' "$f" | sed -n 4p); v6=$(printf '%s\n' "$f" | sed -n 5p)
    state=$(printf '%s\n' "$f" | sed -n 6p); dev=$(printf '%s\n' "$f" | sed -n 7p)
    jq -cn --arg u "$uuid" --arg n "$name" --arg m "$mac" --arg k "$kind" --arg s "$state" --arg d "$dev" \
        --argjson safe "$( [ "$v4" = yes ] && { [ "$v6" = yes ] || [ -z "$v6" ]; } && echo true || echo false)" \
        '{profile: $u, name: $n, bdaddr: $m, type: $k, active: ($s == "activated"), device: $d, safe: $safe}'
}

parse_events() {
    awk '
        function out(s) { print s; fflush() }
        /^signal / {
            member = ""; path = ""
            for (i = 1; i <= NF; i++) { if ($i ~ /^member=/) member = substr($i, 8); if ($i ~ /^path=/) path = substr($i, 6) }
            sub(/;$/, "", path)
            n = split(path, p, "/"); dev = (n >= 5 ? p[5] : "")
            want = member; args = 0; a1 = ""; a2 = ""
            next
        }
        want != "" && /^   (string|boolean|int32) / {
            v = $0; sub(/^   [a-z0-9]+ /, "", v); gsub(/"/, "", v)
            args++; if (args == 1) a1 = v; else a2 = v
            if (want == "deviceVisibilityChanged" && args == 2) { out("{\"e\":\"visible\",\"id\":\"" a1 "\",\"on\":" a2 "}"); want = "" }
            else if (want == "reachableChanged" && args == 1) { out("{\"e\":\"visible\",\"id\":\"" dev "\",\"on\":" a1 "}"); want = "" }
            else if (want == "refreshed" && args == 2) { out("{\"e\":\"battery\",\"id\":\"" dev "\",\"charging\":" a1 ",\"charge\":" a2 "}"); want = "" }
            else if (want == "shareReceived" && args == 1) { out("{\"e\":\"received\",\"id\":\"" dev "\",\"url\":\"" a1 "\"}"); want = "" }
            else if (want == "deviceListChanged" || want == "pairStateChanged") { out("{\"e\":\"list\"}"); want = "" }
        }
        '
}

case ${1:-} in
status)
    all=$(kdeconnect-cli -l --id-name-only 2>/dev/null)
    up=$(kdeconnect-cli -a --id-only 2>/dev/null)
    tether=$(tether_iface || true)
    pandev=$(pan_status | jq -r 'select(.active) | .device')
    [ -n "$pandev" ] && [ "$pandev" = "$tether" ] && tether=""
    backends=$(kdeconnect-cli -b 2>/dev/null | awk -F'|' '{printf "%s\"%s\":%s", (NR>1?",":""), $2, ($3=="enabled"?"true":"false")}')
    cust=$(custom | tr ' ' '\n' | grep -v '^$' | jq -R . | jq -sc .)
    printf '%s\n' "$all" | while IFS= read -r line; do
        [ -n "$line" ] || continue
        id=${line%% *}; name=${line#* }
        reach=false; printf '%s\n' "$up" | grep -qx "$id" && reach=true
        paired=$(prop "$id" "" org.kde.kdeconnect.device isPaired); [ "$paired" = true ] || paired=false
        type=$(prop "$id" "" org.kde.kdeconnect.device type)
        bat=$(prop "$id" /battery org.kde.kdeconnect.device.battery charge)
        chg=$(prop "$id" /battery org.kde.kdeconnect.device.battery isCharging)
        prov=$(prop "$id" "" org.kde.kdeconnect.device activeProviderNames)
        sig=$(prop "$id" /connectivity_report org.kde.kdeconnect.device.connectivity_report cellularNetworkStrength)
        via=wifi
        case $prov in *Bluetooth*) via=bluetooth ;; *) [ -n "$tether" ] && via=usb ;; esac
        [ -n "$pandev" ] && [ "$via" != bluetooth ] && via=bluetooth   # over the phone's Bluetooth network
        [ "$reach" = true ] || via=""
        case $bat in ''|*[!0-9-]*) bat=-1 ;; esac
        case $sig in ''|*[!0-9-]*) sig=-1 ;; esac
        jq -n -c --arg id "$id" --arg name "$name" --arg type "${type:-phone}" --argjson paired "$paired" --argjson reach "$reach" \
            --argjson bat "$bat" --arg chg "${chg:-false}" --arg via "$via" --argjson sig "$sig" \
            '{id: $id, name: $name, type: $type, paired: $paired, reachable: $reach, battery: $bat,
              charging: ($chg == "true"), via: $via, signal: $sig}'
    done | jq -s -c --argjson b "{${backends}}" --argjson c "${cust:-[]}" --arg t "$tether" \
        '{available: true, backends: $b, custom: $c, tether: $t, devices: .}' ;;
doctor)
    running=false; pgrep -u "$(id -u)" -x kdeconnectd >/dev/null && running=true
    dev=$(ip route show default 2>/dev/null | awk '/default/ {for (i=1;i<NF;i++) if ($i=="dev") {print $(i+1); exit}}')
    addr=$(ip -4 -o addr show dev "${dev:-lo}" 2>/dev/null | awk '{print $4; exit}')
    ssid=$(nmcli -t -f ACTIVE,SSID dev wifi 2>/dev/null | awk -F: '$1=="yes" {print $2; exit}')
    # Other machines this laptop has heard from on the local network
    neigh=$(ip neigh show dev "${dev:-lo}" 2>/dev/null | grep -vc FAILED)
    # Firewall: is 1714-1764 open in the active zone? (read-only query; no root)
    fw=unknown
    if command -v firewall-cmd >/dev/null && firewall-cmd --state >/dev/null 2>&1; then
        zone=$(firewall-cmd --get-zone-of-interface="${dev:-lo}" 2>/dev/null || firewall-cmd --get-default-zone 2>/dev/null)
        if firewall-cmd --zone="$zone" --query-service=kdeconnect >/dev/null 2>&1 \
           || firewall-cmd --zone="$zone" --query-port=1716/udp >/dev/null 2>&1 \
           || firewall-cmd --zone="$zone" --list-ports 2>/dev/null | grep -Eq '(^| )1025-65535/udp'; then fw=open; else fw=closed; fi
    fi
    warp=false; ip link show CloudflareWARP >/dev/null 2>&1 && warp=true
    tether=$(tether_iface || true)
    pandev=$(pan_status | jq -r 'select(.active) | .device')
    [ -n "$pandev" ] && [ "$pandev" = "$tether" ] && tether=""
    bt=$(kdeconnect-cli -b 2>/dev/null | awk -F'|' '$2=="bluetooth" {print $3}')
    found=$(kdeconnect-cli -l --id-only 2>/dev/null | grep -c .)
    reach=$(kdeconnect-cli -a --id-only 2>/dev/null | grep -c .)
    jq -n -c --argjson running "$running" --arg dev "${dev:-}" --arg addr "${addr:-}" --arg ssid "${ssid:-}" \
        --argjson neigh "${neigh:-0}" --arg fw "$fw" --argjson warp "$warp" --arg tether "$tether" \
        --arg bt "${bt:-unavailable}" --argjson found "${found:-0}" --argjson reach "${reach:-0}" --argjson custom "$(custom | tr ' ' '\n' | grep -v '^$' | jq -R . | jq -sc .)" \
        '{installed: true, running: $running, iface: $dev, address: $addr, ssid: $ssid, neighbours: $neigh,
          firewall: $fw, warp: $warp, tether: $tether, bluetooth: $bt, found: $found, reachable: $reach, custom: $custom,
          isolated: ($running and $found == 0 and $ssid != "")}' ;;
events)
    # The daemon's signals, as JSON lines. The match rule names the
    # well-known sender, so only KDE Connect's own signals arrive.
    dbus-monitor --session "type='signal',sender='$DEST'" 2>/dev/null | parse_events ;;
parse-events)   # (testing) parse dbus-monitor text from stdin
    parse_events ;;
clip-sync)
    id=${2:?device id}
    printf '%s' "$id" | grep -Eqx '[A-Za-z0-9_-]{1,64}' || exit 2
    path="$OBJ/devices/$id"
    case ${3:-status} in
        on|off)
            v=true; [ "$3" = off ] && v=false
            busctl --user call "$DEST" "$path" org.kde.kdeconnect.device setPluginEnabled sb kdeconnect_clipboard "$v" >/dev/null ;;
        status)
            busctl --user call "$DEST" "$path" org.kde.kdeconnect.device isPluginEnabled s kdeconnect_clipboard 2>/dev/null |
                awk '{print ($2 == "true") ? "on" : "off"}' ;;
        *) exit 2 ;;
    esac ;;
from-phone)
    # KDE Connect's clipboard plugin has no "received" signal. A clipboard
    # change counts as the phone's when kdeconnectd's link just received data.
    ss -tinp state established 2>/dev/null | awk '
        /users:\(\("kdeconnectd"/ { want = 1; next }
        want { want = 0; for (i = 1; i <= NF; i++) if ($i ~ /^lastrcv:/) { v = substr($i, 9) + 0; if (v <= 2500) found = 1 } }
        END { exit found ? 0 : 1 }' ;;
ring|ping|send-clipboard|pair|unpair)
    exec kdeconnect-cli -d "${2:?device id}" "--$1" ;;
share)
    id=${2:?device id}; shift 2
    [ $# -gt 0 ] || { echo "link.sh share <id> <file-or-url>…" >&2; exit 2; }
    for f in "$@"; do kdeconnect-cli -d "$id" --share "$f" || exit 1; done ;;
text)
    exec kdeconnect-cli -d "${2:?device id}" --share-text "${3:?text}" ;;
pick-and-share)
    id=${2:?device id}
    files=$(kdialog --title "Send to your phone" --multiple --separate-output --getopenfilename "$HOME" 2>/dev/null \
            || zenity --file-selection --multiple --separator='
' --title "Send to your phone" 2>/dev/null) || exit 0
    printf '%s\n' "$files" | while IFS= read -r f; do [ -n "$f" ] && kdeconnect-cli -d "$id" --share "$f"; done ;;
screenshot)
    id=${2:?device id}
    out=${XDG_RUNTIME_DIR:-/tmp}/lumen-link-shot-$(date +%s).png
    region=$(slurp 2>/dev/null) || exit 0
    grim -g "$region" "$out" && kdeconnect-cli -d "$id" --share "$out" ;;
add-address)
    ip=${2:?address}; valid_ip "$ip" || { echo "Not an IP address: $ip" >&2; exit 2; }
    # shellcheck disable=SC2046
    set_custom $(custom | tr ' ' '\n' | grep -v '^$' | grep -vx "$ip") "$ip" && kdeconnect-cli --refresh ;;
remove-address)
    ip=${2:?address}
    # shellcheck disable=SC2046
    set_custom $(custom | tr ' ' '\n' | grep -v '^$' | grep -vx "$ip") ;;
backend)
    case ${2:-}:${3:-} in
        lan:on|bluetooth:on) exec kdeconnect-cli --enable-backend "$2" ;;
        lan:off|bluetooth:off) exec kdeconnect-cli --disable-backend "$2" ;;
        *) echo "link.sh backend lan|bluetooth on|off" >&2; exit 2 ;;
    esac ;;
pan)
    case ${2:-status} in
    status) pan_status ;;
    safe)
        uuid=$(pan_profile); [ -n "$uuid" ] || exit 1
        nmcli connection modify "$uuid" ipv4.never-default yes ipv6.never-default yes && echo ok ;;
    up)
        st=$(pan_status)
        uuid=$(printf '%s' "$st" | jq -r .profile)
        [ -n "$uuid" ] || { echo '{"ok":false,"reason":"no-profile"}'; exit 1; }
        [ "$(printf '%s' "$st" | jq -r .safe)" = true ] || { echo '{"ok":false,"reason":"unsafe"}'; exit 1; }
        [ "$(printf '%s' "$st" | jq -r .active)" = true ] && { kdeconnect-cli --refresh >/dev/null 2>&1; echo '{"ok":true,"reason":"already"}'; exit 0; }
        mac=$(printf '%s' "$st" | jq -r .bdaddr)
        if ! bluetoothctl info "$mac" 2>/dev/null | grep -q "Connected: yes"; then
            timeout 12 bluetoothctl connect "$mac" >/dev/null 2>&1 || { echo '{"ok":false,"reason":"away"}'; exit 1; }
        fi
        if out=$(timeout 25 nmcli connection up "$uuid" 2>&1); then
            kdeconnect-cli --refresh >/dev/null 2>&1
            echo '{"ok":true,"reason":"up"}'
        else
            # Usually: the phone's Bluetooth tethering is off
            printf '%s' "$out" | grep -qiE "NAP|not available|refused|no such|Bluetooth" \
                && echo '{"ok":false,"reason":"tethering"}' || echo '{"ok":false,"reason":"failed"}'
            exit 1
        fi ;;
    *) echo "usage: link.sh pan status|up|safe" >&2; exit 2 ;;
    esac ;;
refresh)
    exec kdeconnect-cli --refresh ;;
*)
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
