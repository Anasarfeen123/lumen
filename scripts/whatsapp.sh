#!/bin/sh
# whatsapp.sh — start your WhatsApp app for the WhatsApp scratchpad
# (Super+Shift+Z) when it opens empty. Choice: Settings → WhatsApp → WhatsApp app
#   zapfast   ZapFast, the native app (zapfast.rocks)
#   whatsie   Whatsie (Flatpak)
#   web       WhatsApp Web as a web-app window of your browser
#   auto      ZapFast if installed, else Whatsie, else the web app
pref=$(jq -r '.client // "auto"' "${XDG_STATE_HOME:-$HOME/.local/state}/lumen/whatsapp.json" 2>/dev/null || echo auto)

zapfast() { command -v zapfast >/dev/null && exec zapfast; return 1; }
whatsie() {
    command -v flatpak >/dev/null && flatpak info com.ktechpit.whatsie >/dev/null 2>&1 && exec flatpak run com.ktechpit.whatsie
    return 1
}
web() {
    for b in brave-origin brave-browser brave google-chrome-stable google-chrome chromium-browser chromium; do
        command -v "$b" >/dev/null && exec "$b" --app=https://web.whatsapp.com/
    done
    exec xdg-open https://web.whatsapp.com/
}
case $pref in
    zapfast) zapfast; web ;;
    whatsie) whatsie; web ;;
    web)     web ;;
    *)       zapfast; whatsie; web ;;
esac
