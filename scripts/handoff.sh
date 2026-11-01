#!/bin/sh
# handoff.sh — carry what's playing between this computer and your phone, at
# the same second (Lumen Link / KDE Connect).
#   handoff.sh to-phone [--dry-run]   the PC's player → a link opened on the phone
#                                     (YouTube at the current time), then pause here
#   handoff.sh to-pc [--dry-run]      the phone's player (KDE Connect's media remote) →
#                                     opened here at its time, then pause the phone
# A player that gives its page (xesam:url) is used as it is; otherwise the video
# is found by title and artist with yt-dlp (one YouTube search, only when you
# ask). Prints JSON: {ok, url, title, seconds} or {error}.
set -eu
LUMEN_ROOT=${LUMEN_ROOT:-$HOME/.config/lumen}
dry=0; [ "${2:-}" = --dry-run ] && dry=1

fail() { jq -cn --arg e "$1" '{error: $e}'; exit 1; }
phone() { kdeconnect-cli -a --id-only 2>/dev/null | head -n 1; }
# the video for "title artist", at second $2
find_url() {
    id=$(timeout 20 yt-dlp --no-warnings --skip-download --print id "ytsearch1:$1" 2>/dev/null | head -n 1) || true
    [ -n "$id" ] || return 1
    printf 'https://www.youtube.com/watch?v=%s&t=%ss\n' "$id" "$2"
}
with_time() {   # a YouTube page with &t= at second $2; other pages as they are
    case $1 in
        *youtube.com/watch*|*youtu.be/*) printf '%s\n' "$1" | sed -E 's/[?&]t=[0-9]+s?//; s/$/\&t='"$2"'s/; s/youtu\.be\/([^&?]+)&/youtu.be\/\1?/' ;;
        *) printf '%s\n' "$1" ;;
    esac
}

case ${1:-} in
to-phone)
    p=$(playerctl -l 2>/dev/null | head -n 1); [ -n "$p" ] || fail "Nothing is playing here."
    title=$(playerctl -p "$p" metadata title 2>/dev/null || true)
    artist=$(playerctl -p "$p" metadata artist 2>/dev/null || true)
    url=$(playerctl -p "$p" metadata xesam:url 2>/dev/null || true)
    pos=$(playerctl -p "$p" position 2>/dev/null | cut -d. -f1); pos=${pos:-0}
    case $url in http*) url=$(with_time "$url" "$pos") ;; *) url=$(find_url "$title $artist" "$pos") || fail "Couldn't find \"$title\" on YouTube." ;; esac
    if [ $dry = 0 ]; then
        id=$(phone); [ -n "$id" ] || fail "Your phone isn't reachable (Lumen Link)."
        "$LUMEN_ROOT/scripts/link.sh" share "$id" "$url" >/dev/null 2>&1 || fail "Couldn't send it to the phone."
        playerctl -p "$p" pause 2>/dev/null || true
    fi
    jq -cn --arg u "$url" --arg t "$title" --argjson s "$pos" '{ok: true, url: $u, title: $t, seconds: $s}' ;;
to-pc)
    id=$(phone); [ -n "$id" ] || fail "Your phone isn't reachable (Lumen Link)."
    obj=/modules/kdeconnect/devices/$id/mprisremote
    get() { busctl --user get-property org.kde.kdeconnect "$obj" org.kde.kdeconnect.device.mprisremote "$1" 2>/dev/null | sed -E 's/^[a-z] //; s/^"(.*)"$/\1/'; }
    title=$(get title); artist=$(get artist); ms=$(get position)
    [ -n "$title" ] || fail "Nothing is playing on the phone (or KDE Connect's media control is off there)."
    secs=$(( ${ms:-0} / 1000 ))
    url=$(find_url "$title $artist" "$secs") || fail "Couldn't find \"$title\" on YouTube."
    if [ $dry = 0 ]; then
        xdg-open "$url" >/dev/null 2>&1 &
        busctl --user call org.kde.kdeconnect "$obj" org.kde.kdeconnect.device.mprisremote sendAction s Pause >/dev/null 2>&1 || true
    fi
    jq -cn --arg u "$url" --arg t "$title" --argjson s "$secs" '{ok: true, url: $u, title: $t, seconds: $s}' ;;
*)
    sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
