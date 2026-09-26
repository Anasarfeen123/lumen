#!/bin/sh
# update-admin.sh — the one root action of Lumen's update centre, behind your
# password (Settings runs it with pkexec; polkit asks every time).
#   update-admin.sh upgrade     dnf upgrade --refresh -y   (nothing else is accepted)
set -eu
[ "$(id -u)" = 0 ] || { echo "update-admin.sh: must run as root (via pkexec)" >&2; exit 1; }
[ "${1:-}" = upgrade ] && [ $# -eq 1 ] || { echo "usage: update-admin.sh upgrade" >&2; exit 2; }
exec dnf upgrade --refresh -y
