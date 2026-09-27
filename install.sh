#!/usr/bin/env bash
# Lumen installer — Fedora, Arch (EndeavourOS, CachyOS, Manjaro), Debian /
# Ubuntu (Mint, Pop!_OS), openSUSE. Needs Hyprland 0.56+ (Lumen's config is Lua).
#
#   ./install.sh            guided install: explains every step and asks first
#   ./install.sh --dry-run  show everything it would do, change nothing
#   ./install.sh --yes      accept every step (still shows each command)
#
# What it does, in order (each step can be skipped):
#   1. Hyprland              on Fedora it isn't in the official repos: the Hyprland
#                            project documents the community COPR solopasha/hyprland
#   2. Packages              from your distribution's own repositories (dnf,
#                            pacman, apt, zypper); anything unavailable is listed
#   3. Fonts & cursor        optional downloads of font/cursor FILES (never
#                            scripts) from their official upstream projects
#   4. Link                  ~/.config/lumen → this folder
#   5. Theme                 generate colours and config from theme/tokens.toml
#   6. How to start          a TTY login, a login-screen entry, or by hand
#
# It never pipes anything into a shell, never touches ~/.config/hypr (your
# other Hyprland setup) or KDE, and only uses sudo for dnf and, if you ask,
# the login-screen entry. Undo with ./uninstall.sh.
set -euo pipefail

LUMEN_SRC=$(cd "$(dirname "$0")" && pwd)
DRY=0 YES=0
for a in "$@"; do
    case $a in
        --dry-run) DRY=1 ;;
        --yes|-y) YES=1 ;;
        -h|--help) sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $a (try --help)" >&2; exit 2 ;;
    esac
done

# ── output helpers ──────────────────────────────────────────────────────────
if [ -t 1 ]; then B=$'\e[1m' D=$'\e[2m' A=$'\e[38;5;215m' G=$'\e[32m' R=$'\e[31m' N=$'\e[0m'; else B='' D='' A='' G='' R='' N=''; fi
step=0
title() { step=$((step + 1)); printf '\n%s%s%d. %s%s\n' "$B" "$A" "$step" "$1" "$N"; }
say()   { printf '   %s\n' "$*"; }
note()  { printf '   %s%s%s\n' "$D" "$*" "$N"; }
ok()    { printf '   %s✓%s %s\n' "$G" "$N" "$*"; }
warn()  { printf '   %s!%s %s\n' "$R" "$N" "$*"; }
# ask "question" → 0 for yes
ask() {
    # Dry run: assume yes, so every command is shown (run() won't execute it)
    [ $DRY = 1 ] && { note "? $1 → (dry run: yes)"; return 0; }
    [ $YES = 1 ] && return 0
    local r; printf '   %s%s%s [Y/n] ' "$B" "$1" "$N"; read -r r </dev/tty || r=n
    case ${r:-y} in [Yy]*) return 0 ;; *) return 1 ;; esac
}
# run cmd… — prints the exact command, then runs it (not in a dry run)
run() {
    printf '   %s$ %s%s\n' "$D" "$(printf '%q ' "$@")" "$N"
    [ $DRY = 1 ] && return 0
    "$@"
}
have() { command -v "$1" >/dev/null 2>&1; }
# Font families, read once (grep -q on a live pipe + pipefail = false negatives)
FONTS=$(fc-list : family 2>/dev/null || true)
hasfont() { grep -qi -- "$1" <<<"$FONTS"; }

# ── 0. checks ───────────────────────────────────────────────────────────────
printf '%s%sLumen%s — a calm, capable Hyprland desktop\n' "$B" "$A" "$N"
[ $DRY = 1 ] && note "Dry run: nothing will be changed."
[ "$(id -u)" != 0 ] || { warn "Run this as your normal user (it asks for sudo only when needed)."; exit 1; }
OS_RELEASE=${LUMEN_OS_RELEASE:-/etc/os-release}      # (overridable for testing)
# shellcheck disable=SC1090
. "$OS_RELEASE"
# Distro family → package manager. ID_LIKE covers derivatives (Mint, Pop!_OS,
# EndeavourOS, CachyOS, Manjaro, Nobara, …).
FAMILY=other
for id in ${ID:-} ${ID_LIKE:-}; do
    case $id in
        fedora|rhel|nobara|ultramarine) FAMILY=fedora; break ;;
        arch|archlinux|endeavouros|cachyos|manjaro|garuda) FAMILY=arch; break ;;
        debian|ubuntu|linuxmint|pop|elementary|zorin) FAMILY=debian; break ;;
        opensuse*|suse|sles) FAMILY=suse; break ;;
    esac
done
case $FAMILY in
    fedora) PM="dnf";    PM_INSTALL=(sudo dnf install -y) ;;
    arch)   PM="pacman"; PM_INSTALL=(sudo pacman -S --needed --noconfirm) ;;
    debian) PM="apt";    PM_INSTALL=(sudo apt-get install -y) ;;
    suse)   PM="zypper"; PM_INSTALL=(sudo zypper --non-interactive install) ;;
    *)      PM="" ;;
esac
say "System: ${PRETTY_NAME:-unknown} ${D}(${FAMILY}${PM:+, $PM})${N}"
say "Source: $LUMEN_SRC"
note "Nothing in ~/.config/hypr, KDE or another desktop is changed."
[ "$FAMILY" = fedora ] || note "Lumen is developed on Fedora; on ${PRETTY_NAME:-this system} it's installed the same way, but less tested."

# Is a package available in the configured repositories?
available() {
    case $FAMILY in
        fedora) dnf -q info "$1" >/dev/null 2>&1 ;;
        arch)   pacman -Si "$1" >/dev/null 2>&1 ;;
        debian) [ -n "$(apt-cache policy "$1" 2>/dev/null | awk '/Candidate:/ {print $2}' | grep -v '(none)')" ] ;;
        suse)   zypper -q info "$1" 2>/dev/null | grep -q '^Name' ;;
        *)      return 1 ;;
    esac
}
# Hyprland ≥ 0.56 is needed (Lumen's config is Lua)
hypr_version() { Hyprland --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1; }
hypr_ok() { local v; v=$(hypr_version); [ -n "$v" ] && printf '0.56.0\n%s\n' "$v" | sort -V -C; }

# ── 1. Hyprland ─────────────────────────────────────────────────────────────
title "Hyprland"
if have Hyprland && hypr_ok; then
    ok "Hyprland $(hypr_version) is installed."
elif have Hyprland; then
    warn "Hyprland $(hypr_version) is too old — Lumen needs 0.56 or newer (its config is Lua)."
    note "Update it from your distribution (or the source below), then run this again."
else
    case $FAMILY in
    fedora)
        say "Hyprland is not packaged in Fedora's official repositories."
        say "The Hyprland project's install guide points Fedora users to the community"
        say "COPR ${B}solopasha/hyprland${N} (Fedora's build service; packages are built from"
        say "upstream sources). Enabling it adds one repository file in /etc/yum.repos.d."
        ask "Enable the solopasha/hyprland COPR?" && run sudo dnf copr enable -y solopasha/hyprland ;;
    arch)   say "Hyprland is in Arch's official ${B}extra${N} repository — installed in the next step." ;;
    suse)   say "Hyprland is in openSUSE Tumbleweed's official repositories — installed in the next step." ;;
    debian) say "Debian and Ubuntu package Hyprland, but usually an older release than Lumen needs (0.56+)."
            say "The next step installs what your release has, and this installer checks the version after." ;;
    *)      warn "Unknown distribution — install Hyprland (0.56+) from hyprland.org's guide, then run this again." ;;
    esac
fi

# ── 2. Packages ─────────────────────────────────────────────────────────────
title "Packages"
# check|why|fedora|arch|debian|suse   (check: a command, font:NAME, or file:PATH)
DEPS=(
  "Hyprland|the compositor (windows, animations, blur)|hyprland|hyprland|hyprland|hyprland"
  "hyprlock|fallback lock screen if the Lumen shell isn't running|hyprlock|hyprlock|hyprlock|hyprlock"
  "hypridle|idle: dim, lock, screen off, sleep|hypridle|hypridle|hypridle|hypridle"
  "hyprsunset|night light|hyprsunset|hyprsunset|hyprsunset|hyprsunset"
  "hyprpicker|colour picker|hyprpicker|hyprpicker|hyprpicker|hyprpicker"
  "portal|screen sharing, file pickers for Flatpak apps|xdg-desktop-portal-hyprland|xdg-desktop-portal-hyprland|xdg-desktop-portal-hyprland|xdg-desktop-portal-hyprland"
  "qs|the Lumen shell (bar, island, sidebars, settings) runs on Quickshell|quickshell|quickshell|quickshell|quickshell"
  "kitty|terminal|kitty|kitty|kitty|kitty"
  "grim|screenshots|grim|grim|grim|grim"
  "slurp|pick a region of the screen|slurp|slurp|slurp|slurp"
  "swappy|annotate screenshots|swappy|swappy|swappy|swappy"
  "wf-recorder|screen recording|wf-recorder|wf-recorder|wf-recorder|wf-recorder"
  "wl-copy|copy and paste from scripts|wl-clipboard|wl-clipboard|wl-clipboard|wl-clipboard"
  "cliphist|clipboard history|cliphist|cliphist|cliphist|cliphist"
  "brightnessctl|screen and keyboard brightness|brightnessctl|brightnessctl|brightnessctl|brightnessctl"
  "playerctl|media keys|playerctl|playerctl|playerctl|playerctl"
  "pw-play|interface sounds|pipewire-utils|pipewire|pipewire-bin|pipewire-tools"
  "tesseract|copy text from the screen (OCR)|tesseract|tesseract|tesseract-ocr|tesseract-ocr"
  "ocr-eng|English for OCR|tesseract-langpack-eng|tesseract-data-eng|tesseract-ocr-eng|tesseract-ocr-traineddata-english"
  "magick|thumbnails and image scaling|ImageMagick|imagemagick|imagemagick|ImageMagick"
  "jq|reading JSON in scripts|jq|jq|jq|jq"
  "inotifywait|download progress in the island|inotify-tools|inotify-tools|inotify-tools|inotify-tools"
  "curl|weather and optional downloads|curl|curl|curl|curl"
  "font:JetBrains Mono|monospace font|jetbrains-mono-fonts-all|ttf-jetbrains-mono|fonts-jetbrains-mono|jetbrains-mono-fonts"
  "kdialog|file dialogs (profile picture)|kdialog|kdialog|kdialog|kdialog"
  "notify-send|notifications from scripts|libnotify|libnotify|libnotify-bin|libnotify-tools"
  "python3|generates the theme (standard library only)|python3|python|python3|python3"
)
present() {
    case $1 in
        font:*) hasfont "${1#font:}" ;;
        portal) [ -x /usr/libexec/xdg-desktop-portal-hyprland ] || [ -x /usr/lib/xdg-desktop-portal-hyprland ] || [ -x /usr/lib/x86_64-linux-gnu/xdg-desktop-portal-hyprland ] ;;
        ocr-eng) have tesseract && tesseract --list-langs 2>/dev/null | grep -qx eng ;;
        *) have "$1" ;;
    esac
}
col=0; case $FAMILY in fedora) col=3 ;; arch) col=4 ;; debian) col=5 ;; suse) col=6 ;; esac
need=() unavail=()
for e in "${DEPS[@]}"; do
    IFS='|' read -r chk why pf pa pd ps <<<"$e"
    present "$chk" && continue
    case $col in 3) pkg=$pf ;; 4) pkg=$pa ;; 5) pkg=$pd ;; 6) pkg=$ps ;; *) pkg="" ;; esac
    if [ -n "$pkg" ] && available "$pkg"; then need+=("$pkg|$why"); else unavail+=("${pkg:-$chk}|$why"); fi
done
if [ ${#need[@]} -eq 0 ] && [ ${#unavail[@]} -eq 0 ]; then
    ok "Everything is already installed."
fi
if [ ${#need[@]} -gt 0 ]; then
    say "To install from your distribution's repositories:"
    for e in "${need[@]}"; do printf '     %s%-34s%s %s\n' "$B" "${e%%|*}" "$N" "${e#*|}"; done
    names=(); for e in "${need[@]}"; do names+=("${e%%|*}"); done
    if ask "Install them with $PM?"; then
        [ "$FAMILY" = debian ] && run sudo apt-get update
        run "${PM_INSTALL[@]}" "${names[@]}"
        [ $DRY = 1 ] || FONTS=$(fc-list : family 2>/dev/null || true)
    else
        warn "Skipped — Lumen needs these to run."
    fi
fi
if [ ${#unavail[@]} -gt 0 ]; then
    warn "Not available from your configured repositories:"
    for e in "${unavail[@]}"; do printf '     %s%-34s%s %s\n' "$B" "${e%%|*}" "$N" "${e#*|}"; done
    case $FAMILY in
        arch)   note "On Arch these usually live in the AUR — install them with your AUR helper (read the PKGBUILD first)." ;;
        debian) note "Quickshell isn't packaged for Debian/Ubuntu yet: build it from quickshell.org (\"Building\")." ;;
        *)      note "Install them from the project's own instructions, then run this again." ;;
    esac
fi
# After installing, the Hyprland version matters more than the package name
if have Hyprland && ! hypr_ok; then
    warn "Installed Hyprland is $(hypr_version); Lumen needs 0.56+. Everything else is set up, but"
    warn "Lumen won't start on this version — update Hyprland first."
fi

# ── 3. Fonts & cursor ───────────────────────────────────────────────────────
title "Fonts & cursor (optional downloads)"
FONT_DIR=$HOME/.local/share/fonts/lumen
ICON_DIR=$HOME/.local/share/icons
fetch() {   # fetch url dest — a plain file download (no execution), then verify its type
    run curl -fL --proto '=https' --tlsv1.2 --max-time 120 -o "$2" "$1"
}
if hasfont "Material Symbols Rounded"; then
    ok "Material Symbols Rounded (Lumen's icons) is installed."
else
    say "${B}Material Symbols Rounded${N} draws every icon in Lumen. It isn't in Fedora's repos;"
    say "it comes from Google's official repository github.com/google/material-design-icons"
    say "(Apache 2.0). One .ttf file goes to $FONT_DIR."
    if ask "Download it?"; then
        run mkdir -p "$FONT_DIR"
        fetch "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf" \
              "$FONT_DIR/MaterialSymbolsRounded.ttf" || warn "Couldn't download it — icons will show as text until it's installed."
        [ $DRY = 1 ] || [ ! -e "$FONT_DIR/MaterialSymbolsRounded.ttf" ] || file -b "$FONT_DIR/MaterialSymbolsRounded.ttf" | grep -qi "font" || { warn "That didn't look like a font — removed."; rm -f "$FONT_DIR/MaterialSymbolsRounded.ttf"; }
    fi
fi
if hasfont "Google Sans Flex"; then
    ok "Google Sans Flex (the UI font) is installed."
else
    say "The UI font is ${B}Google Sans Flex${N} (SIL Open Font License), from Google Fonts'"
    say "official repository github.com/google/fonts. Without it Lumen uses your default sans."
    if ask "Download it?"; then
        run mkdir -p "$FONT_DIR"
        fetch "https://github.com/google/fonts/raw/main/ofl/googlesansflex/GoogleSansFlex%5BGRAD,ROND,opsz,slnt,wdth,wght%5D.ttf" \
              "$FONT_DIR/GoogleSansFlex.ttf" || warn "Couldn't fetch it — Lumen will use your default font."
    fi
fi
if [ -d /usr/share/icons/Bibata-Modern-Classic ] || [ -d "$ICON_DIR/Bibata-Modern-Classic" ]; then
    ok "Bibata cursor is installed."
else
    say "Lumen's pointer is ${B}Bibata Modern${N} (GPL-3.0), from its author's official releases at"
    say "github.com/ful1e5/Bibata_Cursor. A cursor theme is just images; it goes to $ICON_DIR."
    if ask "Download it?"; then
        tmp=$(mktemp -d); run mkdir -p "$ICON_DIR"
        fetch "https://github.com/ful1e5/Bibata_Cursor/releases/latest/download/Bibata-Modern-Classic.tar.xz" "$tmp/bibata.tar.xz" &&
            run tar -xJf "$tmp/bibata.tar.xz" -C "$ICON_DIR" --no-same-owner || warn "Couldn't install the cursor — the default one stays."
        rm -rf -- "$tmp"
    fi
fi
[ $DRY = 1 ] || fc-cache -f "$FONT_DIR" >/dev/null 2>&1 || true

# ── 4. Link ─────────────────────────────────────────────────────────────────
title "Link the config"
LINK=$HOME/.config/lumen
if [ -L "$LINK" ] && [ "$(readlink -f "$LINK")" = "$LUMEN_SRC" ]; then
    ok "$LINK already points here."
elif [ -e "$LINK" ]; then
    warn "$LINK exists and isn't a link to this folder. Move it aside first — nothing changed."
    exit 1
else
    say "Lumen lives in this folder; ~/.config/lumen will point to it."
    ask "Create the link?" && run ln -s "$LUMEN_SRC" "$LINK"
fi

# ── 5. Theme ────────────────────────────────────────────────────────────────
title "Generate the theme"
say "Builds colours, Hyprland tokens, terminal and prompt themes into generated/."
run python3 "$LUMEN_SRC/theme/build.py"

# ── 6. How to start ─────────────────────────────────────────────────────────
title "How to start Lumen"
say "a) ${B}A TTY${N}: log in on a text console (e.g. Ctrl+Alt+F3) and Lumen starts."
say "   Adds a small, clearly marked block to ~/.bash_profile (removed by uninstall.sh)."
say "b) ${B}Login screen${N}: adds a “Lumen” session to GDM/SDDM (needs sudo; one file in"
say "   /usr/share/wayland-sessions)."
say "c) ${B}By hand${N}: run ~/.config/lumen/bin/lumen-session from a TTY (or inside another"
say "   desktop, where it opens in a window for trying things out)."
choice=c
if [ $DRY = 0 ] && [ $YES = 0 ]; then
    printf '   %sWhich? [a/b/c]%s ' "$B" "$N"; read -r choice </dev/tty || choice=c
elif [ $DRY = 1 ]; then note "? Which → (dry run: c — shown here without changing anything)"; fi
case ${choice:-c} in
a|A)
    printf '   %sWhich TTY number? [3]%s ' "$B" "$N"; read -r vt </dev/tty || vt=3; vt=${vt:-3}
    case $vt in [1-9]) ;; *) warn "Not a TTY number — skipped."; vt= ;; esac
    if [ -n "$vt" ] && ! grep -q '# >>> lumen tty' "$HOME/.bash_profile" 2>/dev/null; then
        block="
# >>> lumen tty$vt >>>
# Logging in on tty$vt (Ctrl+Alt+F$vt) starts the Lumen desktop. Other TTYs and
# graphical logins are unaffected. Remove this block (or run uninstall.sh) to undo.
if [ -z \"\${WAYLAND_DISPLAY:-}\" ] && [ \"\${XDG_VTNR:-}\" = $vt ] && [ -x \"\$HOME/.config/lumen/bin/lumen-session\" ]; then
    mkdir -p \"\$HOME/.cache\"
    exec \"\$HOME/.config/lumen/bin/lumen-session\" > \"\$HOME/.cache/lumen-session.log\" 2>&1
fi
# <<< lumen tty$vt <<<"
        say "Appending to ~/.bash_profile:"; printf '%s%s%s\n' "$D" "$block" "$N"
        [ $DRY = 1 ] || printf '%s\n' "$block" >> "$HOME/.bash_profile"
        ok "Log in on tty$vt (Ctrl+Alt+F$vt) to start Lumen."
    elif [ -n "$vt" ]; then ok "A Lumen TTY block is already in ~/.bash_profile."; fi ;;
b|B)
    tmpd=$(mktemp); printf '[Desktop Entry]\nName=Lumen\nComment=A calm, capable Hyprland desktop\nExec=%s/.config/lumen/bin/lumen-session\nType=Application\nDesktopNames=Hyprland\n' "$HOME" > "$tmpd"
    say "Session file:"; sed 's/^/     /' "$tmpd"
    run sudo install -m 644 "$tmpd" /usr/share/wayland-sessions/lumen.desktop; rm -f "$tmpd"
    ok "Pick “Lumen” on your login screen." ;;
*)
    ok "Start it with: ~/.config/lumen/bin/lumen-session" ;;
esac

# ── Done ────────────────────────────────────────────────────────────────────
printf '\n%s%sDone.%s\n' "$B" "$G" "$N"
say "When Lumen starts for the first time, a short welcome walks you through the look, your phone, Halo and five keys."
say "First steps: tap ${B}Super${N} to search · ${B}Super+/${N} for every shortcut · ${B}Super+I${N} for Settings."
say "Optional extras (never installed automatically):"
note "• Face ID on the lock screen — Gaze (gaze.gundulabs.com), then Settings → Face ID"
note "• Local AI — Ollama (ollama.com), then Settings → AI; or Claude with your own key"
note "• Qt apps in Lumen colours — sudo dnf install qt6ct"
say "Undo everything: ${B}./uninstall.sh${N}"
