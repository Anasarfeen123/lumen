#!/bin/sh
# updates.sh — what can be updated, as JSON for Lumen (no root needed).
#   updates.sh check     {"dnf":[{name,arch,version,repo,security}], "flatpak":[{id,name,version}], "reboot":bool}
#   updates.sh flatpak   update Flatpak apps (system installs ask via polkit)
# System packages are installed by scripts/update-admin.sh through pkexec.
set -eu
case ${1:-} in
check)
    out=$(dnf check-upgrade --quiet 2>/dev/null) && rc=0 || rc=$?
    [ "$rc" = 0 ] || [ "$rc" = 100 ] || { echo '{"error":"dnf check failed"}'; exit 0; }
    sec=$(dnf advisory list --updates --json 2>/dev/null || echo '[]')
    printf '%s\n' "$out" | awk 'NF==3 && $1 ~ /\./ { n=$1; sub(/\.[^.]*$/, "", n); a=$1; sub(/^.*\./, "", a); printf "%s\t%s\t%s\t%s\n", n, a, $2, $3 }' |
    jq -R -s --argjson sec "$sec" '
        [ split("\n")[] | select(length > 0) | split("\t") | {name: .[0], arch: .[1], version: .[2], repo: .[3]} ] as $pk
        | ($sec | map(select((.type // "") == "security") | (.nevra // .package // "")) ) as $secnevras
        | [ $pk[] | . + {security: ([ $secnevras[] | startswith(.name + "-") ] | any)} ]' > "${XDG_RUNTIME_DIR:-/tmp}/lumen-dnf.json"
    fp=$(flatpak remote-ls --updates --columns=application,name,version 2>/dev/null |
         jq -R -s '[ split("\n")[] | select(length > 0) | split("\t") | {id: .[0], name: (.[1] // .[0]), version: (.[2] // "")} ]' || echo '[]')
    jq -c --argjson fp "$fp" '{dnf: ., flatpak: $fp, reboot: ([.[].name] | any(test("^(kernel|kernel-core|glibc|systemd|mesa-.*|nvidia.*|akmod-nvidia)$")))}' \
        "${XDG_RUNTIME_DIR:-/tmp}/lumen-dnf.json" ;;
flatpak)
    exec flatpak update -y --noninteractive ;;
*)
    sed -n '2,5p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
