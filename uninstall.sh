#!/usr/bin/env bash
# Lumen uninstaller — undoes what install.sh set up, asking before each step.
#   ./uninstall.sh            guided
#   ./uninstall.sh --dry-run  show what it would remove
# It removes: the ~/.config/lumen link, the Lumen block in ~/.bash_profile,
# the login-screen entry, and fonts/cursor Lumen downloaded. It does NOT
# remove packages (other software may use them) or this folder, and never
# touches ~/.config/hypr or KDE. Your Lumen preferences stay in
# ~/.local/state/lumen (delete that folder yourself for a clean slate).
set -euo pipefail
DRY=0; [ "${1:-}" = --dry-run ] && DRY=1
say() { printf '   %s\n' "$*"; }
ask() { [ $DRY = 1 ] && { say "(dry run — would ask: $1)"; return 1; }; local r; printf '   %s [y/N] ' "$1"; read -r r </dev/tty || r=n; [[ ${r:-n} == [Yy]* ]]; }
run() { printf '   $ %s\n' "$(printf '%q ' "$@")"; [ $DRY = 1 ] || "$@"; }

echo "Lumen — uninstall"
LINK=$HOME/.config/lumen
if [ -L "$LINK" ]; then ask "Remove the ~/.config/lumen link (the folder it points to stays)?" && run rm -- "$LINK"; fi
if grep -q '# >>> lumen tty' "$HOME/.bash_profile" 2>/dev/null; then
    say "~/.bash_profile has a Lumen TTY block."
    if ask "Remove it?"; then
        run cp -- "$HOME/.bash_profile" "$HOME/.bash_profile.lumen-bak"
        [ $DRY = 1 ] || sed -i '/^# >>> lumen tty[0-9]* >>>$/,/^# <<< lumen tty[0-9]* <<<$/d' "$HOME/.bash_profile"
        say "Removed (backup: ~/.bash_profile.lumen-bak)."
    fi
fi
if [ -e /usr/share/wayland-sessions/lumen.desktop ]; then ask "Remove the “Lumen” login-screen entry (sudo)?" && run sudo rm -- /usr/share/wayland-sessions/lumen.desktop; fi
if [ -d "$HOME/.local/share/fonts/lumen" ]; then ask "Remove fonts Lumen downloaded (~/.local/share/fonts/lumen)?" && run rm -r -- "$HOME/.local/share/fonts/lumen"; fi
if [ -d "$HOME/.local/share/icons/Bibata-Modern-Classic" ]; then ask "Remove the Bibata cursor Lumen downloaded (~/.local/share/icons/Bibata-Modern-Classic)?" && run rm -r -- "$HOME/.local/share/icons/Bibata-Modern-Classic"; fi
echo "Done. Packages were left installed; remove them with dnf if you like."
