#!/bin/sh
# update-admin.sh — the one root action of Lumen's update centre, behind your
# password (Settings runs it with pkexec; polkit asks every time).
#   update-admin.sh upgrade     full system upgrade with your package manager:
#                               dnf upgrade --refresh -y · pacman -Syu · apt-get update && upgrade · zypper up/dup
#   (nothing else is accepted)
set -eu
[ "$(id -u)" = 0 ] || { echo "update-admin.sh: must run as root (via pkexec)" >&2; exit 1; }
[ "${1:-}" = upgrade ] && [ $# -eq 1 ] || { echo "usage: update-admin.sh upgrade" >&2; exit 2; }
if command -v dnf >/dev/null; then exec dnf upgrade --refresh -y
elif command -v pacman >/dev/null; then exec pacman -Syu --noconfirm
elif command -v apt-get >/dev/null; then apt-get update && exec env DEBIAN_FRONTEND=noninteractive apt-get -y upgrade
elif command -v zypper >/dev/null; then
    . /etc/os-release
    case ${ID:-} in opensuse-tumbleweed|opensuse-slowroll) exec zypper --non-interactive dup ;; *) exec zypper --non-interactive update ;; esac
else echo "update-admin.sh: no supported package manager" >&2; exit 1; fi
