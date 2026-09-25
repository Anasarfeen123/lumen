#!/bin/sh
# idle.sh — every hypridle step goes through here.
#   idle.sh dim | undim | lock | screen-off | screen-on | suspend [--battery-only]
#
# Each step first checks that THIS login session is the one on screen. If you
# have switched to another session (another tty, KDE, illogical-impulse), this
# one sees no input and would think you're away: without the check it would
# dim your backlight and suspend the whole laptop under you.
set -eu

active() {
    [ -n "${XDG_SESSION_ID:-}" ] || return 0
    [ "$(loginctl show-session "$XDG_SESSION_ID" -p Active --value 2>/dev/null)" = yes ]
}

on_charger() {
    for ps in /sys/class/power_supply/*; do
        case $(cat "$ps/type" 2>/dev/null || true) in
            Mains|USB|USB_C|USB_PD) [ "$(cat "$ps/online" 2>/dev/null || echo 0)" = 1 ] && return 0 ;;
        esac
    done
    return 1
}

active || exit 0
case ${1:-} in
    dim)        brightnessctl -s set 20% >/dev/null ;;
    undim)      brightnessctl -r >/dev/null ;;
    lock)       loginctl lock-session ;;
    screen-off) hyprctl dispatch 'hl.dsp.dpms("off")' >/dev/null ;;
    screen-on)  hyprctl dispatch 'hl.dsp.dpms("on")' >/dev/null; brightnessctl -r >/dev/null ;;
    suspend)
        [ "${2:-}" = --battery-only ] && on_charger && exit 0
        exec systemctl suspend ;;
    *) sed -n '3p' "$0" >&2; exit 2 ;;
esac
