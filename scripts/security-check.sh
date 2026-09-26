#!/bin/sh
# security-check.sh — a read-only check-up for Settings → Security, as JSON.
# Each item: {id, state: "good"|"warn"|"info", value, hint}. No root needed;
# nothing is changed.
set -u
item() { jq -n -c --arg id "$1" --arg state "$2" --arg value "$3" --arg hint "$4" '{id: $id, state: $state, value: $value, hint: $hint}'; }
out=""
add() { out="$out$1
"; }

if systemctl is-active -q firewalld 2>/dev/null; then add "$(item firewall good "On" "firewalld is filtering incoming connections")"
elif systemctl is-active -q ufw 2>/dev/null; then add "$(item firewall good "On" "ufw is filtering incoming connections")"
else add "$(item firewall warn "Off" "Turn on a firewall: sudo systemctl enable --now firewalld")"; fi

if systemctl is-active -q sshd 2>/dev/null || systemctl is-active -q ssh 2>/dev/null; then
    add "$(item ssh warn "Running" "Remote logins are possible. If you don't use SSH: sudo systemctl disable --now sshd")"
else add "$(item ssh good "Off" "No remote login service is running")"; fi

sb=$(mokutil --sb-state 2>/dev/null | head -1)
case $sb in *enabled*) add "$(item secureboot good "On" "Only signed boot loaders and kernels can start")" ;;
            *disabled*) add "$(item secureboot info "Off" "Enable it in your firmware (UEFI) settings if your drivers are signed")" ;;
            *) add "$(item secureboot info "Unknown" "Couldn't read the firmware state")" ;; esac

if lsblk -rno TYPE,FSTYPE 2>/dev/null | grep -qE '^crypt|crypto_LUKS'; then add "$(item encryption good "On" "Your disk is encrypted (LUKS)")"
else add "$(item encryption warn "Off" "A lost laptop exposes your files; encryption is chosen when installing")"; fi

se=$(getenforce 2>/dev/null || echo "")
case $se in Enforcing) add "$(item selinux good "Enforcing" "SELinux confines system services")" ;;
            Permissive) add "$(item selinux warn "Permissive" "SELinux only logs; set SELINUX=enforcing in /etc/selinux/config")" ;;
            Disabled) add "$(item selinux warn "Disabled" "SELinux is off")" ;;
            *) aa=$(cat /sys/module/apparmor/parameters/enabled 2>/dev/null); [ "$aa" = Y ] && add "$(item selinux good "AppArmor" "AppArmor confines applications")" ;; esac

if journalctl -b _PID=1 -n1 -q >/dev/null 2>&1; then
    n=$(journalctl -b --no-pager -q -g 'authentication failure|FAILED LOGIN|Failed password' 2>/dev/null | wc -l)
    [ "$n" -eq 0 ] && add "$(item logins good "0 since boot" "No failed password attempts")" \
                   || add "$(item logins warn "$n since boot" "Failed password attempts — review with: journalctl -b -g 'authentication failure'")"
else add "$(item logins info "Hidden" "Only administrators can read the system log")"; fi

if command -v fwupdmgr >/dev/null; then add "$(item firmware info "fwupd" "Firmware updates come through GNOME Software / Discover")"; fi
printf '%s' "$out" | jq -s -c '.'
