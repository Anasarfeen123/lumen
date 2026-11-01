#!/bin/sh
# lumen-sync.sh — your whole setup as one file, to carry to another computer
# (or keep): theme and accent, every setting, launcher pins and shortcuts,
# planner, Halo's memory and routines, notes, clipboard pins, the wallpaper,
# your local.lua / session.env.
#   lumen-sync.sh export [file]    default ~/lumen-setup-<date>.tar.gz
#   lumen-sync.sh import <file>    first saves what it replaces to
#                                  ~/.local/state/lumen/before-import-<date>.tar.gz
#   lumen-sync.sh list <file>      what's inside
#   lumen-sync.sh theme-export [file]   just the look, to share: theme, accent, glass, corners,
#                                       gaps, border and the wallpaper (~/lumen-theme-<accent>.tar.gz)
#   lumen-sync.sh theme-import <file>   apply someone's look (your settings otherwise untouched)
# Never in it: API keys, mail and 2FA accounts, AmazeCC's login (all in your
# keyring or key files), screen time, notification history. Notes import
# never overwrites a note that's newer on this computer.
set -eu
LUMEN_ROOT=${LUMEN_ROOT:-$HOME/.config/lumen}
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/lumen
NOTES=$(jq -r '.dir // empty' "$STATE/notes.json" 2>/dev/null || true); NOTES=${NOTES:-$HOME/Notes}
FILES="state.json shell.json planner.json launcher.json whatsapp.json amazecc.json clip-pins notes.md snapshots wallpaper"

stage() {   # copy what's exported into $1 (a temp dir)
    mkdir -p "$1/state" "$1/config"
    for f in $FILES; do [ -e "$STATE/$f" ] && cp -a "$STATE/$f" "$1/state/"; done
    for f in local.lua session.env; do [ -e "$LUMEN_ROOT/$f" ] && cp -a "$LUMEN_ROOT/$f" "$1/config/"; done
    # your widgets and their lockfile
    W=${XDG_DATA_HOME:-$HOME/.local/share}/lumen/widgets
    [ -d "$W" ] && cp -a "$W" "$1/widgets"
    # notes, without the trash or Syncthing's folder markers (they belong to this computer's sync)
    if [ -d "$NOTES" ]; then
        cp -a "$NOTES" "$1/notes"
        rm -rf "$1/notes/.trash" "$1/notes/.stfolder" "$1/notes/.stignore" "$1/notes/.stversions"
    fi
    # the wallpaper itself, when it isn't one of the system's
    wp=$(cat "$STATE/wallpaper" 2>/dev/null || true)
    case $wp in /usr/*|"") ;; *) [ -f "$wp" ] && { mkdir -p "$1/wallpaper"; cp -a "$wp" "$1/wallpaper/"; } ;; esac
    printf '{"made":"%s","from":"%s","notes":"%s"}\n' "$(date -Is)" "$(hostname)" "$NOTES" > "$1/lumen-setup.json"
}

LOOK_KEYS='["theme","accent","accent_intensity","accent_style","transparency","glass_level","corners","gaps","border","wallpaper_hue"]'

case ${1:-} in
theme-export)
    acc=$(jq -r '.accent // "lumen"' "$STATE/state.json" 2>/dev/null || echo lumen)
    out=${2:-$HOME/lumen-theme-$acc.tar.gz}
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    mkdir -p "$tmp/lumen-theme"
    jq --argjson k "$LOOK_KEYS" 'with_entries(select(.key as $x | $k | index($x)))' "$STATE/state.json" > "$tmp/lumen-theme/look.json"
    wp=$(cat "$STATE/wallpaper" 2>/dev/null || true)
    [ -f "$wp" ] && cp "$wp" "$tmp/lumen-theme/wallpaper.${wp##*.}"
    tar -czf "$out" -C "$tmp" lumen-theme
    echo "$out" ;;
theme-import)
    in=${2:?usage: lumen-sync.sh theme-import <file>}
    tar -tzf "$in" lumen-theme/look.json >/dev/null 2>&1 || { echo "Not a Lumen theme: $in" >&2; exit 1; }
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    tar -xzf "$in" -C "$tmp"
    cp "$STATE/state.json" "$STATE/state.json.before-theme-$(date +%Y%m%d-%H%M%S)"
    jq -s --argjson k "$LOOK_KEYS" '.[0] + (.[1] | with_entries(select(.key as $x | $k | index($x))))' "$STATE/state.json" "$tmp/lumen-theme/look.json" > "$STATE/state.json.tmp" \
        && mv "$STATE/state.json.tmp" "$STATE/state.json"
    for w in "$tmp"/lumen-theme/wallpaper.*; do
        [ -f "$w" ] || continue
        d=$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Wallpapers; mkdir -p "$d"
        name="theme-$(basename "$in" .tar.gz).${w##*.}"; cp "$w" "$d/$name"
        "$LUMEN_ROOT/scripts/wallpaper.sh" set "$d/$name" >/dev/null 2>&1 || printf '%s\n' "$d/$name" > "$STATE/wallpaper"
    done
    echo "Theme applied — run: lumen reload" ;;
export)
    out=${2:-$HOME/lumen-setup-$(date +%Y-%m-%d).tar.gz}
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    stage "$tmp/lumen-setup"
    umask 077
    tar -czf "$out" -C "$tmp" lumen-setup
    echo "$out" ;;
list)
    tar -tzf "${2:?usage: lumen-sync.sh list <file>}" | sed 's|^lumen-setup/||' | grep -v '/$' | head -200 ;;
import)
    in=${2:?usage: lumen-sync.sh import <file>}
    tar -tzf "$in" lumen-setup/lumen-setup.json >/dev/null 2>&1 || { echo "Not a Lumen setup file: $in" >&2; exit 1; }
    tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
    # what's here now, kept first
    stage "$tmp/before"
    keep="$STATE/before-import-$(date +%Y-%m-%d_%H-%M-%S).tar.gz"
    (umask 077; tar -czf "$keep" -C "$tmp" before)
    tar -xzf "$in" -C "$tmp"
    src=$tmp/lumen-setup
    mkdir -p "$STATE"
    for f in $FILES; do [ -e "$src/state/$f" ] && cp -a "$src/state/$f" "$STATE/"; done
    for f in local.lua session.env; do [ -e "$src/config/$f" ] && cp -a "$src/config/$f" "$LUMEN_ROOT/"; done
    if [ -d "$src/widgets" ]; then W=${XDG_DATA_HOME:-$HOME/.local/share}/lumen/widgets; mkdir -p "$W"; cp -a -n "$src/widgets/." "$W/"; fi
    if [ -d "$src/notes" ]; then mkdir -p "$NOTES"; cp -a --update=older "$src/notes/." "$NOTES/" 2>/dev/null || cp -a -u "$src/notes/." "$NOTES/"; fi
    if [ -d "$src/wallpaper" ]; then
        d=$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")/Wallpapers; mkdir -p "$d"
        for w in "$src"/wallpaper/*; do cp -a "$w" "$d/"; printf '%s\n' "$d/${w##*/}" > "$STATE/wallpaper"; done
    fi
    python3 "$LUMEN_ROOT/theme/build.py" >/dev/null 2>&1 || true
    echo "Imported. What was here before: $keep — now run: lumen reload" ;;
*)
    sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
