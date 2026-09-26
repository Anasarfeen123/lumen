#!/bin/sh
# halo-rename.sh — apply (or undo) the file renames Lumen Halo suggested,
# only after you pressed "Apply renames". Nothing else calls it.
#
#   halo-rename.sh apply <plan.json>   plan: [{ "from": "/abs/dir/old.pdf", "to": "new name.pdf" }]
#   halo-rename.sh undo  <plan.json>   the "done" list printed by apply, reversed
#
# Rules (checked here, whatever the model said):
#   • "to" is a bare file name: no "/", not "." or "..", not hidden, ≤ 200 bytes,
#     no control characters — the file stays in its own folder
#   • the original extension is kept (added back if the new name dropped it)
#   • an existing file is never overwritten (mv -n, and checked first)
# Output: JSON lines {"from","to","status":"renamed"|"skipped","why"?}
set -u

one() {   # one <from> <to-basename>
    from=$1; to=$2
    case $from in /*) ;; *) jq -cn --arg f "$from" --arg t "$to" '{from:$f,to:$t,status:"skipped",why:"not an absolute path"}'; return ;; esac
    [ -f "$from" ] || { jq -cn --arg f "$from" --arg t "$to" '{from:$f,to:$t,status:"skipped",why:"file not found"}'; return; }
    bad=""
    case $to in ""|.|..|.*|*/*) bad="not a plain file name" ;; esac
    [ -z "$bad" ] && [ "$(printf '%s' "$to" | wc -c)" -gt 200 ] && bad="name too long"
    [ -z "$bad" ] && printf '%s' "$to" | LC_ALL=C grep -q '[[:cntrl:]]' && bad="control characters"
    if [ -n "$bad" ]; then jq -cn --arg f "$from" --arg t "$to" --arg w "$bad" '{from:$f,to:$t,status:"skipped",why:$w}'; return; fi
    dir=${from%/*}; base=${from##*/}
    # keep the extension
    case $base in *.*) ext=${base##*.}; case $to in *."$ext") ;; *) to="$to.$ext" ;; esac ;; esac
    dest="$dir/$to"
    if [ "$dest" = "$from" ]; then jq -cn --arg f "$from" --arg t "$dest" '{from:$f,to:$t,status:"skipped",why:"same name"}'; return; fi
    if [ -e "$dest" ]; then jq -cn --arg f "$from" --arg t "$dest" '{from:$f,to:$t,status:"skipped",why:"a file with that name exists"}'; return; fi
    if mv -n -- "$from" "$dest" 2>/dev/null && [ -e "$dest" ] && [ ! -e "$from" ]; then
        jq -cn --arg f "$from" --arg t "$dest" '{from:$f,to:$t,status:"renamed"}'
    else
        jq -cn --arg f "$from" --arg t "$dest" '{from:$f,to:$t,status:"skipped",why:"rename failed"}'
    fi
}

plan=${2:-}
[ -f "$plan" ] || { echo "usage: halo-rename.sh apply|undo <plan.json>" >&2; exit 2; }
case ${1:-} in
apply)
    jq -r '.[] | [.from, .to] | @tsv' "$plan" | while IFS="$(printf '\t')" read -r f t; do one "$f" "$t"; done ;;
undo)
    # plan here is the list of results; put each renamed file back to its old name
    jq -r '.[] | select(.status == "renamed") | [.to, (.from | split("/") | last)] | @tsv' "$plan" |
        while IFS="$(printf '\t')" read -r f t; do one "$f" "$t"; done ;;
*) echo "usage: halo-rename.sh apply|undo <plan.json>" >&2; exit 2 ;;
esac
