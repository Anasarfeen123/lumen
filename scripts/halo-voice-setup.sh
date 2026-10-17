#!/bin/sh
# halo-voice-setup.sh — a natural voice for Halo: Piper (offline neural speech).
#
# Started from Settings → Halo → Voice, in a terminal you can read. It shows
# every command and asks before running anything. What it does:
#   1. makes a Python environment just for Piper:   ~/.local/share/lumen/piper
#      (no sudo, nothing system-wide; delete that folder to remove it all)
#   2. installs Piper into it from PyPI:            pip install piper-tts
#      (https://pypi.org/project/piper-tts — the Open Home Foundation's Piper)
#   3. downloads voices from Piper's own voice repository on Hugging Face
#      (https://huggingface.co/rhasspy/piper-voices) into
#      ~/.local/share/lumen/voices
# Speech then runs entirely on this computer.
#
#   halo-voice-setup.sh            the whole thing
#   halo-voice-setup.sh voice <name>   just one more voice (e.g. en_GB-alan-medium)
set -eu

DATA=${XDG_DATA_HOME:-$HOME/.local/share}/lumen
VENV=$DATA/piper
VOICES=$DATA/voices
HF=https://huggingface.co/rhasspy/piper-voices/resolve/main

bold() { printf '\033[1m%s\033[0m\n' "$*"; }
dim() { printf '\033[2m%s\033[0m\n' "$*"; }
run() { printf '\033[36m$ %s\033[0m\n' "$*"; "$@"; }
ask() { printf '%s [y/N] ' "$1"; read -r a; [ "$a" = y ] || [ "$a" = Y ]; }

# en_US-lessac-medium → en/en_US/lessac/medium/en_US-lessac-medium
voice_path() {
    name=$1
    lang=${name%%-*}                   # en_US
    rest=${name#*-}                    # lessac-medium
    speaker=${rest%-*}                 # lessac
    quality=${rest##*-}                # medium
    printf '%s/%s/%s/%s/%s' "${lang%%_*}" "$lang" "$speaker" "$quality" "$name"
}
get_voice() {
    p=$(voice_path "$1")
    mkdir -p "$VOICES"
    run curl -fL --progress-bar -o "$VOICES/$1.onnx" "$HF/$p.onnx"
    run curl -fL --progress-bar -o "$VOICES/$1.onnx.json" "$HF/$p.onnx.json"
}

if [ "${1:-}" = voice ] && [ -n "${2:-}" ]; then
    get_voice "$2"; exit 0
fi

bold "A natural voice for Halo (Piper)"
echo
echo "This will:"
echo "  1. make a Python environment just for Piper in $VENV"
echo "  2. install the piper-tts package into it from PyPI (about 40 MB)"
echo "  3. download two voices (about 60 MB each) into $VOICES:"
echo "       en_US-lessac-medium   warm, clear (Friendly / Calm)"
echo "       en_GB-alan-medium     British, composed (Jarvis)"
echo
dim "Nothing needs sudo. To undo: rm -rf \"$VENV\" \"$VOICES\""
echo
ask "Go ahead?" || { echo "Nothing changed."; exit 0; }
echo

command -v python3 >/dev/null || { echo "python3 is missing (sudo dnf install python3)"; exit 1; }
[ -x "$VENV/bin/python" ] || run python3 -m venv "$VENV"
run "$VENV/bin/python" -m pip install --upgrade --quiet pip
run "$VENV/bin/python" -m pip install --quiet piper-tts
echo
get_voice en_US-lessac-medium
get_voice en_GB-alan-medium
echo
bold "Done — Halo now speaks with Piper."
dim "Try it: Settings → Halo → Voice → Test. Close this window when you like."
