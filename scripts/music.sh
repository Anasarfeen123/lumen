#!/bin/sh
# music.sh — start your music app for the music scratchpad (Super+Shift+M)
# when it opens empty. Choice: Settings → Sound → Music app
#   ytmrs     ytm-rs, a native YouTube Music app (github.com/grapedjuice/ytm-rs;
#             its install.sh puts it in ~/.local/bin)
#   ytmusic   YouTube Music as a web-app window of your browser (your profile,
#             so you're signed in) — Brave Origin, Brave, Chrome or Chromium
#   spotify   Spotify (Flatpak or native)
#   auto      ytm-rs if installed, else Spotify, else YouTube Music, else a local player
pref=$(jq -r '.musicApp // "auto"' "${XDG_STATE_HOME:-$HOME/.local/state}/lumen/shell.json" 2>/dev/null || echo auto)

ytmrs() {
    for b in ytm-rs "$HOME/.local/bin/ytm-rs" "$HOME/.local/lib/ytm-rs/ytm-rs"; do
        command -v "$b" >/dev/null && exec "$b"
    done
    return 1
}
ytmusic() {
    for b in brave-origin brave-browser brave google-chrome-stable google-chrome chromium-browser chromium; do
        command -v "$b" >/dev/null && exec "$b" --app=https://music.youtube.com
    done
    return 1
}
spotify() {
    if command -v flatpak >/dev/null && flatpak info com.spotify.Client >/dev/null 2>&1; then exec flatpak run com.spotify.Client; fi
    command -v spotify >/dev/null && exec spotify
    return 1
}
case $pref in
    ytmrs)   ytmrs; ytmusic ;;
    ytmusic) ytmusic ;;
    spotify) spotify ;;
    *)       ytmrs; spotify; ytmusic ;;
esac
for app in elisa rhythmbox lollypop amberol g4music strawberry audacious; do
    command -v "$app" >/dev/null && exec "$app"
done
exec notify-send -a Lumen "No music app found" "Choose one in Settings → Sound, or install a browser for YouTube Music."
