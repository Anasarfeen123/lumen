#!/bin/sh
# lyrics.sh <artist> <title> [album] [seconds] — lyrics for the island, from
# LRCLIB (lrclib.net: free, no account). Prints one JSON object:
#   {"found":true,"synced":"[00:12.34] …","plain":"…","instrumental":false}
#   {"found":false}
# Only the song's artist, title, album and length are sent, and only when the
# island asks (its now-playing view is open, and Settings → Sound → Lyrics is on).
# Answers, including "not found", are cached in ~/.cache/lumen/lyrics so a song
# is looked up once. Nothing else is run or written.
set -u
artist=${1:-}; title=${2:-}; album=${3:-}; secs=${4:-}
cache=${XDG_CACHE_HOME:-$HOME/.cache}/lumen/lyrics
api=https://lrclib.net/api

nothing() { echo '{"found":false}'; exit 0; }
[ -n "$artist" ] && [ -n "$title" ] || nothing
# Plain text only, of sane length
for v in "$artist" "$title" "$album"; do
    [ "${#v}" -le 300 ] || nothing
    case $v in *[[:cntrl:]]*) nothing ;; esac
done
case $secs in ''|*[!0-9]*) secs="" ;; esac

key=$(printf '%s|%s' "$artist" "$title" | tr '[:upper:]' '[:lower:]' | sha1sum | cut -c1-40)
mkdir -p "$cache" && chmod 700 "$cache"
if [ -s "$cache/$key.json" ]; then cat "$cache/$key.json"; exit 0; fi

enc() { jq -rn --arg v "$1" '$v | @uri'; }
get() { curl -fsS --max-time 6 -H 'User-Agent: Lumen (https://github.com/Anasarfeen123/lumen)' "$1" 2>/dev/null; }
shape='{found: ((.syncedLyrics // .plainLyrics // "") != "" or (.instrumental // false)),
        synced: (.syncedLyrics // ""), plain: (.plainLyrics // ""), instrumental: (.instrumental // false)}'

q="artist_name=$(enc "$artist")&track_name=$(enc "$title")"
[ -n "$album" ] && q="$q&album_name=$(enc "$album")"
[ -n "$secs" ] && q="$q&duration=$secs"
out=$(get "$api/get?$q" | jq -c "$shape" 2>/dev/null)
# No exact match (album or length differ): search, prefer a synced result
if [ -z "$out" ] || [ "$(printf '%s' "$out" | jq -r .found)" != true ]; then
    out=$(get "$api/search?track_name=$(enc "$title")&artist_name=$(enc "$artist")" |
          jq -c "(map(select((.syncedLyrics // \"\") != \"\")) + .)[0] // {} | $shape" 2>/dev/null)
fi
# Offline or the service is down: say nothing, and don't cache (try again later)
[ -n "$out" ] || nothing
printf '%s\n' "$out" > "$cache/$key.json"
printf '%s\n' "$out"
