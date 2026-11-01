#!/bin/sh
# lumen-widgets.sh — your own widgets (docs/WIDGETS.md) and their lockfile.
#   lumen widgets list                 what's installed, what kind, on or off
#   lumen widgets new <id> [card|desktop]   start one from the template
#   lumen widgets examples             copy Lumen's examples in (they stay off)
#   lumen widgets add <git-url> [ref]  install from a git repository: shows every file
#                                      and asks first; recorded in widgets.lock at its commit
#   lumen widgets sync                 install what widgets.lock lists (a new computer),
#                                      each at its recorded commit, checked by its hash
#   lumen widgets remove <id>          to the trash (asks first)
#   lumen widgets check <id>           why it didn't load (the shell's log)
# Widgets live in ~/.local/share/lumen/widgets/<id>/ (widget.json + QML). New ones
# are off until you turn them on in Settings → Appearance → Your widgets.
set -eu
LUMEN_ROOT=${LUMEN_ROOT:-$HOME/.config/lumen}
DIR=${XDG_DATA_HOME:-$HOME/.local/share}/lumen/widgets
LOCK=$DIR/widgets.lock
mkdir -p "$DIR"
[ -f "$LOCK" ] || echo '[]' > "$LOCK"

changed() { date +%s > "$DIR/.changed"; }                 # the shell looks again
valid_id() { printf '%s' "$1" | grep -Eq '^[a-z0-9][a-z0-9._-]{0,40}$' || { echo "A widget id is lowercase letters, digits, . _ - (got: $1)" >&2; exit 2; }; }
# one hash for a widget folder: every file's sha256, by path
hash_dir() { (cd "$1" && find . -type f ! -path './.git/*' | LC_ALL=C sort | xargs -d '\n' sha256sum | sha256sum | cut -d' ' -f1); }
ask() { printf '%s [y/N] ' "$1"; read -r a < /dev/tty || a=""; [ "$a" = y ] || [ "$a" = Y ]; }

case ${1:-} in
list)
    on=$(jq -r '.widgetsEnabled // [] | .[]' "${XDG_STATE_HOME:-$HOME/.local/state}/lumen/shell.json" 2>/dev/null || true)
    found=0
    for f in "$DIR"/*/widget.json; do
        [ -f "$f" ] || continue; found=1
        d=${f%/widget.json}; id=${d##*/}
        state=off; printf '%s\n' "$on" | grep -qx "$id" && state=on
        src=$(jq -r --arg id "$id" '.[] | select(.id == $id) | "\(.source)@\(.commit[0:7])"' "$LOCK")
        printf '%-22s %-8s %-4s %s\n' "$id" "$(jq -r '.kind' "$f")" "$state" "${src:-local}"
    done
    [ $found = 1 ] || echo "No widgets yet: lumen widgets new <id>, or lumen widgets examples" ;;
new)
    id=${2:?usage: lumen widgets new <id> [card|desktop]}; valid_id "$id"
    kind=${3:-card}; case $kind in card|desktop) ;; *) echo "kind: card or desktop" >&2; exit 2 ;; esac
    [ -e "$DIR/$id" ] && { echo "$DIR/$id already exists" >&2; exit 1; }
    mkdir -p "$DIR/$id"
    jq -n --arg n "$id" --arg k "$kind" '{name: $n, description: "", kind: $k, entry: "main.qml", needs: [], version: "0.1"}' > "$DIR/$id/widget.json"
    cp "$LUMEN_ROOT/share/widgets/template.qml" "$DIR/$id/main.qml"
    changed
    echo "$DIR/$id — edit main.qml, then turn it on in Settings → Appearance → Your widgets" ;;
examples)
    for d in "$LUMEN_ROOT"/share/widgets/*/; do
        id=$(basename "$d"); [ -e "$DIR/$id" ] && { echo "$id: already there"; continue; }
        cp -r "$d" "$DIR/$id"; echo "$id: copied (off — turn it on in Settings)"
    done
    changed ;;
add)
    url=${2:?usage: lumen widgets add <git-url> [ref]}; ref=${3:-}
    case $url in https://*|git@*) ;; *) echo "Give an https:// or git@ URL" >&2; exit 2 ;; esac
    [ -t 0 ] || [ -r /dev/tty ] || { echo "lumen widgets add asks before installing: run it in a terminal" >&2; exit 1; }
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    git -c core.hooksPath=/dev/null clone --quiet ${ref:+--branch "$ref"} --depth 1 -- "$url" "$tmp/src"
    commit=$(git -C "$tmp/src" rev-parse HEAD)
    [ -f "$tmp/src/widget.json" ] || { echo "No widget.json at the top of that repository" >&2; exit 1; }
    id=$(basename "$url" .git | tr 'A-Z' 'a-z'); valid_id "$id"
    [ -e "$DIR/$id" ] && { echo "$id is already installed (lumen widgets remove $id first)" >&2; exit 1; }
    echo "$url @ ${commit%"${commit#???????}"} — \"$(jq -r '.name // ""' "$tmp/src/widget.json")\", $(jq -r '.kind' "$tmp/src/widget.json")"
    echo "Files (all of this would run inside your shell once you turn it on):"
    (cd "$tmp/src" && find . -type f ! -path './.git/*' | sed 's|^\./|  |')
    echo "Read them first: ls $tmp/src  (kept until you answer)"
    ask "Install $id?" || { echo "Nothing installed."; exit 0; }
    rm -rf "$tmp/src/.git"; cp -r "$tmp/src" "$DIR/$id"
    h=$(hash_dir "$DIR/$id")
    jq --arg id "$id" --arg s "$url" --arg c "$commit" --arg h "$h" 'map(select(.id != $id)) + [{id: $id, source: $s, commit: $c, sha256: $h}]' "$LOCK" > "$LOCK.tmp" && mv "$LOCK.tmp" "$LOCK"
    changed
    echo "Installed $id (off). Turn it on in Settings → Appearance → Your widgets." ;;
sync)
    n=$(jq length "$LOCK"); [ "$n" = 0 ] && { echo "widgets.lock lists nothing"; exit 0; }
    jq -c '.[]' "$LOCK" | while IFS= read -r e; do
        id=$(printf '%s' "$e" | jq -r .id); src=$(printf '%s' "$e" | jq -r .source); c=$(printf '%s' "$e" | jq -r .commit); want=$(printf '%s' "$e" | jq -r .sha256)
        valid_id "$id"
        if [ -d "$DIR/$id" ]; then
            [ "$(hash_dir "$DIR/$id")" = "$want" ] && { echo "$id: up to date"; continue; }
            echo "$id: differs from widgets.lock (edited here?) — left as it is"; continue
        fi
        tmp=$(mktemp -d)
        git -c core.hooksPath=/dev/null clone --quiet -- "$src" "$tmp/src" && git -C "$tmp/src" -c advice.detachedHead=false checkout --quiet "$c" || { echo "$id: couldn't fetch $src @ $c"; rm -rf "$tmp"; continue; }
        rm -rf "$tmp/src/.git"
        if [ "$(hash_dir "$tmp/src")" = "$want" ]; then cp -r "$tmp/src" "$DIR/$id"; echo "$id: installed @ ${c%"${c#???????}"} (off)"
        else echo "$id: the files at that commit don't match widgets.lock — not installed"; fi
        rm -rf "$tmp"
    done
    changed ;;
remove)
    id=${2:?usage: lumen widgets remove <id>}; valid_id "$id"
    [ -d "$DIR/$id" ] || { echo "No widget $id" >&2; exit 1; }
    ask "Move $id to the trash?" || exit 0
    gio trash "$DIR/$id"
    jq --arg id "$id" 'map(select(.id != $id))' "$LOCK" > "$LOCK.tmp" && mv "$LOCK.tmp" "$LOCK"
    changed; echo "$id is in the trash" ;;
check)
    id=${2:?usage: lumen widgets check <id>}; valid_id "$id"
    pid=""
    for p in $(pgrep -u "$(id -u)" -x qs); do
        tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -Eq 'lumen/shell/?( |$)' && tr '\0' '\n' < "/proc/$p/environ" 2>/dev/null | grep -qx "HYPRLAND_INSTANCE_SIGNATURE=${HYPRLAND_INSTANCE_SIGNATURE:-}" && pid=$p
    done
    [ -n "$pid" ] || { echo "No Lumen shell in this session" >&2; exit 1; }
    out=$(timeout 10 qs log --pid "$pid" 2>/dev/null | sed 's/\x1b\[[0-9;]*m//g' | grep -F "widgets/$id/" | tail -8)
    [ -n "$out" ] && printf '%s\n' "$out" || echo "Nothing about $id in the shell's log (is it turned on?)" ;;
*)
    sed -n '2,15p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
