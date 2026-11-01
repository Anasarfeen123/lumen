#!/bin/sh
# login-admin.sh — the login screen's wallpaper (Plasma Login Manager), through
# pkexec (polkit asks for your admin password every time). The greeter itself
# stays KDE's; Lumen only gives it a picture, in a drop-in file of its own.
#
#   login-admin.sh apply <image>   copy it to /usr/share/wallpapers/Lumen/ and point
#                                  /etc/plasmalogin.conf.d/50-lumen.conf at it
#   login-admin.sh remove          delete both: back to KDE's default
set -eu
[ "$(id -u)" = 0 ] || { echo "login-admin.sh: must run as root (via pkexec)" >&2; exit 1; }
DIR=/usr/share/wallpapers/Lumen/contents/images
CONF=/etc/plasmalogin.conf.d/50-lumen.conf
case ${1:-} in
    apply)
        src=${2:?usage: login-admin.sh apply <image>}
        [ -f "$src" ] && [ ! -L "$src" ] || { echo "login-admin.sh: not a plain file: $src" >&2; exit 1; }
        case $(file -b --mime-type -- "$src") in image/jpeg) ext=jpg ;; image/png) ext=png ;; *) echo "login-admin.sh: only JPEG or PNG" >&2; exit 1 ;; esac
        [ "$(stat -c %s -- "$src")" -le 41943040 ] || { echo "login-admin.sh: image over 40 MB" >&2; exit 1; }
        mkdir -p "$DIR" /etc/plasmalogin.conf.d
        rm -f "$DIR"/login.*
        install -m 644 -o root -g root -- "$src" "$DIR/login.$ext"
        printf '%s\n' "# Lumen: the login screen's wallpaper (scripts/login-admin.sh remove → KDE's default)" \
            "[Greeter][Wallpaper][org.kde.image][General]" "Image=file://$DIR/login.$ext" "PreviewImage=file://$DIR/login.$ext" > "$CONF"
        chmod 644 "$CONF"
        echo "ok" ;;
    remove)
        rm -f "$CONF"; rm -rf /usr/share/wallpapers/Lumen
        echo "ok" ;;
    *)
        sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
