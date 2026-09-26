#!/bin/sh
# drive.sh — the island's actions for a plugged-in drive, through udisks
# (the same service file managers use; no root, no sudo).
#   drive.sh open  /dev/sdX1   mount if needed, then show it in the file manager
#   drive.sh eject /dev/sdX1   unmount every partition of its disk, then power it off
set -u
LUMEN_ROOT=${LUMEN_ROOT:-$HOME/.config/lumen}
ipc() { "$LUMEN_ROOT/bin/lumen-shell-ipc" island event "$@" >/dev/null 2>&1 || true; }

dev=${2:-}
case $dev in /dev/*) ;; *) echo "usage: drive.sh open|eject /dev/…" >&2; exit 2 ;; esac
[ -b "$dev" ] || { ipc usb_off "Drive not found" "It may have been removed"; exit 1; }

mountpoint() { findmnt -nro TARGET --source "$1" 2>/dev/null | head -n 1; }

case ${1:-} in
    open)
        mp=$(mountpoint "$dev")
        if [ -z "$mp" ]; then
            udisksctl mount -b "$dev" --no-user-interaction >/dev/null 2>&1 \
                || { ipc error "Couldn't open the drive" "Its file system may not be supported"; exit 1; }
            mp=$(mountpoint "$dev")
        fi
        [ -n "$mp" ] && exec xdg-open "$mp" ;;
    eject)
        disk=/dev/$(lsblk -no PKNAME "$dev" 2>/dev/null | head -n 1)
        [ "$disk" = /dev/ ] && disk=$dev
        for part in $(lsblk -lnpo NAME "$disk"); do
            [ -n "$(mountpoint "$part")" ] || continue
            udisksctl unmount -b "$part" --no-user-interaction >/dev/null 2>&1 \
                || { ipc warning "Drive is busy" "Close the files on it, then eject again"; exit 1; }
        done
        udisksctl power-off -b "$disk" --no-user-interaction >/dev/null 2>&1 || true
        ipc eject "Safe to remove" "You can unplug the drive now" ;;
    *) echo "usage: drive.sh open|eject /dev/…" >&2; exit 2 ;;
esac
