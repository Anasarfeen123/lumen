#!/bin/sh
# updates.sh — what can be updated, as JSON for Lumen (no root needed).
#   updates.sh check     {"dnf":[{name,arch,version,repo,security}], "flatpak":[…], "reboot":bool}
#                        ("dnf" = system packages from dnf, pacman, apt or zypper)
#   updates.sh flatpak   update Flatpak apps (system installs ask via polkit)
# System packages are installed by scripts/update-admin.sh through pkexec.
set -eu
case ${1:-} in
check)
    # System packages → "name<TAB>arch<TAB>version<TAB>repo" lines, per package manager
    if command -v dnf >/dev/null; then
        out=$(dnf check-upgrade --quiet 2>/dev/null) && rc=0 || rc=$?
        [ "$rc" = 0 ] || [ "$rc" = 100 ] || { echo '{"error":"dnf check failed"}'; exit 0; }
        rows=$(printf '%s\n' "$out" | awk 'NF==3 && $1 ~ /\./ { n=$1; sub(/\.[^.]*$/, "", n); a=$1; sub(/^.*\./, "", a); printf "%s\t%s\t%s\t%s\n", n, a, $2, $3 }')
        sec=$(dnf advisory list --updates --json 2>/dev/null || echo '[]')
    elif command -v pacman >/dev/null; then
        # checkupdates (pacman-contrib) uses a private copy of the database: no root, no partial upgrade
        command -v checkupdates >/dev/null || { echo '{"error":"Install pacman-contrib for update checks"}'; exit 0; }
        rows=$(checkupdates 2>/dev/null | awk '{ printf "%s\t\t%s\t%s\n", $1, $4, "arch" }')
        sec='[]'
    elif command -v apt >/dev/null; then
        rows=$(apt list --upgradable 2>/dev/null | awk -F'[/ ]' 'NR>1 && NF>3 { printf "%s\t%s\t%s\t%s\n", $1, $4, $3, $2 }')
        sec='[]'
    elif command -v zypper >/dev/null; then
        rows=$(zypper -q lu 2>/dev/null | awk -F'|' 'NF>=6 && $1 ~ /v/ { gsub(/ /, ""); printf "%s\t%s\t%s\t%s\n", $3, $6, $5, $2 }')
        sec='[]'
    else
        rows=''; sec='[]'
    fi
    printf '%s\n' "$rows" | jq -R -s --argjson sec "$sec" '
        [ split("\n")[] | select(length > 0) | split("\t") | {name: .[0], arch: .[1], version: .[2], repo: .[3]} ] as $pk
        | ($sec | map(select((.type // "") == "security") | (.nevra // .package // "")) ) as $secnevras
        | [ $pk[] | . + {security: ([ $secnevras[] | startswith(.name + "-") ] | any)} ]' > "${XDG_RUNTIME_DIR:-/tmp}/lumen-dnf.json"
    fp='[]'
    command -v flatpak >/dev/null && fp=$(flatpak remote-ls --updates --columns=application,name,version 2>/dev/null |
         jq -R -s '[ split("\n")[] | select(length > 0) | split("\t") | {id: .[0], name: (.[1] // .[0]), version: (.[2] // "")} ]' || echo '[]')
    jq -c --argjson fp "$fp" '{dnf: ., flatpak: $fp, reboot: ([.[].name] | any(test("^(kernel|kernel-core|linux|linux-lts|linux-zen|linux-image-.*|glibc|libc6|systemd|mesa.*|nvidia.*|akmod-nvidia)$")))}' \
        "${XDG_RUNTIME_DIR:-/tmp}/lumen-dnf.json" ;;
flatpak)
    exec flatpak update -y --noninteractive ;;
*)
    sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
