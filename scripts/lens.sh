#!/bin/sh
# Circle to Search helper. Commands return JSON after completion.
# shot MONITOR OUT | crop IN X Y W H OUT | ocr IMAGE | copy-image IMAGE
# copy-text TEXT | save IMAGE | keep IMAGE OUT | clean SESSION-DIRECTORY
# The shell uses lens.py directly; this entry point is kept for CLI use.
set -eu
exec python3 "${LUMEN_ROOT:-$HOME/.config/lumen}/scripts/lens.py" "$@"
