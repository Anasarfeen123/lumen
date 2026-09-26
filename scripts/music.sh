#!/bin/sh
# music.sh — start a music app for the music scratchpad (Super+Shift+M) when
# it opens empty: Spotify (Flatpak or native), then common players.
if command -v flatpak >/dev/null && flatpak info com.spotify.Client >/dev/null 2>&1; then exec flatpak run com.spotify.Client; fi
for app in spotify elisa rhythmbox lollypop amberol g4music strawberry audacious; do
    command -v "$app" >/dev/null && exec "$app"
done
exec notify-send -a Lumen "No music app found" "Install Spotify, Elisa or Rhythmbox — Super+Shift+M opens it here."
