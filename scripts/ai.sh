#!/bin/sh
# ai.sh — Lumen Halo's only connection to a model.
#
#   ai.sh ask <request.json>     stream an answer as JSON lines: {"t":"text"} … {"s":{n,ms}} or {"e":"error"}
#   ai.sh capture <out.jpg>      screenshot of the focused monitor, scaled for a model
#   ai.sh set-key anthropic      read an API key from stdin, store it (mode 600)
#   ai.sh forget-key anthropic   delete the stored key
#   ai.sh status                 which providers are usable
#   ai.sh warm <model>           load a local model now, so the first answer is quick
#   ai.sh pull <model>           download a local model from Ollama's registry: {"p":0-100,"st":"…"} lines
#   ai.sh rm <model>             delete a local model
#
# request.json: { provider: "anthropic"|"ollama", model, system,
#                 messages: [{ role, text, image?: "/path.jpg" }] }
# The API key is read from ~/.local/state/lumen/ai/anthropic.key and passed to
# curl on stdin, never on the command line. Nothing else leaves the machine.
# Model downloads (pull) come only from the registry Ollama itself uses.
set -eu
DIR=${XDG_STATE_HOME:-$HOME/.local/state}/lumen/ai
KEY="$DIR/anthropic.key"
OLLAMA=${LUMEN_OLLAMA_URL:-http://127.0.0.1:11434}
err() { jq -cn --arg e "$1" '{e:$e}'; exit 1; }

case ${1:-} in
set-key)
    [ "${2:-}" = anthropic ] || { echo "usage: ai.sh set-key anthropic" >&2; exit 2; }
    mkdir -p "$DIR"; chmod 700 "$DIR"
    umask 077
    IFS= read -r k || true
    k=$(printf '%s' "$k" | tr -d '[:space:]')
    case $k in sk-ant-*) printf '%s' "$k" > "$KEY"; echo saved ;; *) echo "That doesn't look like an Anthropic key (sk-ant-…)" >&2; exit 1 ;; esac ;;
forget-key)
    rm -f "$KEY"; echo forgotten ;;
status)
    a=no; [ -s "$KEY" ] && a=yes
    o=no; curl -fsS --max-time 1 "$OLLAMA/api/tags" >/dev/null 2>&1 && o=yes
    models=$( [ $o = yes ] && curl -fsS --max-time 2 "$OLLAMA/api/tags" | jq -c '[.models[].name]' || echo '[]')
    jq -cn --arg a "$a" --arg o "$o" --argjson m "$models" '{anthropic:($a=="yes"), ollama:($o=="yes"), ollamaModels:$m}' ;;
warm)
    m=${2:?}
    jq -cn --arg m "$m" '{model:$m, keep_alive:"15m"}' |
      curl -fsS --max-time 60 -H 'content-type: application/json' --data-binary @- "$OLLAMA/api/generate" >/dev/null 2>&1 || true ;;
pull|rm)
    m=${2:?}
    # model names only: letters, digits, . _ - : and one optional namespace /
    printf '%s' "$m" | grep -Eq '^[A-Za-z0-9._-]+(/[A-Za-z0-9._-]+)?(:[A-Za-z0-9._-]+)?$' || err "Not a model name: $m"
    if [ "$1" = rm ]; then
        jq -cn --arg m "$m" '{model:$m}' | curl -fsS -X DELETE -H 'content-type: application/json' --data-binary @- "$OLLAMA/api/delete" >/dev/null && echo '{"p":100,"st":"removed"}' || err "Couldn't remove $m"
        exit 0
    fi
    jq -cn --arg m "$m" '{model:$m, stream:true}' |
      curl -sS -N --max-time 7200 -H 'content-type: application/json' --data-binary @- "$OLLAMA/api/pull" 2>/dev/null |
      jq -c --unbuffered 'if .error then {e:.error}
                          elif .total and .completed then {p:((.completed * 100 / .total) | floor), st:.status}
                          else {st:.status} end' || err "Couldn't reach Ollama at $OLLAMA" ;;
capture)
    out=${2:?}
    mon=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
    grim -o "$mon" - | magick - -resize '1568x1568>' -quality 82 "$out" ;;
ask)
    req=${2:?}
    provider=$(jq -r .provider "$req")
    model=$(jq -r .model "$req")
    body=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/lumen-ai-body.XXXXXX"); trap 'rm -f "$body"' EXIT
    # Images → base64 (jq builds the provider's message format)
    case $provider in
    anthropic)
        [ -s "$KEY" ] || err "No Anthropic API key yet — add one in Settings → AI."
        jq -c '
          def content: if .image then [ {type:"image", source:{type:"base64", media_type:"image/jpeg", data:(.image | $imgs[.])}}, {type:"text", text:.text} ] else .text end;
          {model, max_tokens:2048, stream:true, system, messages:[.messages[] | {role, content:content}]}' \
          --argjson imgs "$(jq -r '[.messages[].image // empty] | unique | .[]' "$req" | while IFS= read -r f; do
                jq -n --arg f "$f" --arg d "$(base64 -w0 "$f")" '{($f):$d}'; done | jq -s 'add // {}')" \
          "$req" > "$body"
        printf 'x-api-key: %s\nanthropic-version: 2023-06-01\ncontent-type: application/json\n' "$(cat "$KEY")" |
          curl -sS -N --max-time 180 -H @- --data-binary @"$body" https://api.anthropic.com/v1/messages |
          sed -un -e 's/^data: //p' -e '/^{/p' |
          jq -c --unbuffered 'if .type=="content_block_delta" then {t:.delta.text}
                              elif .type=="error" then {e:.error.message} else empty end' ;;
    ollama)
        jq -c --argjson imgs "$(jq -r '[.messages[].image // empty] | unique | .[]' "$req" | while IFS= read -r f; do
                jq -n --arg f "$f" --arg d "$(base64 -w0 "$f")" '{($f):$d}'; done | jq -s 'add // {}')" \
          '{model, stream:true, messages:([{role:"system", content:.system}] + [.messages[] | {role, content:.text} + (if .image then {images:[$imgs[.image]]} else {} end)])}' \
          "$req" > "$body"
        curl -sS -N --max-time 300 -H 'content-type: application/json' --data-binary @"$body" "$OLLAMA/api/chat" 2>/dev/null |
          jq -c --unbuffered 'if .error then {e:.error}
                              elif .done then {s:{n:(.eval_count // 0), ms:((.eval_duration // 0) / 1000000 | floor)}}
                              else {t:(.message.content // "")} end' ||
          err "Couldn't reach Ollama at $OLLAMA — is it running? (ollama serve)" ;;
    mock)   # dev/showcase only: a canned, streamed answer (no network)
        for chunk in "That error means " "**the port is already in use** — another process is listening on \`:8080\`.\n\n" \
                     "**Fix it:**\n\n1. Find it: \`ss -ltnp | grep 8080\`\n" "2. Stop that process, or start yours on another port\n\n" \
                     "Nothing here is destructive; check what the process is before you stop it."; do
            t=$(printf '%bx' "$chunk"); jq -cn --arg t "${t%x}" '{t:$t}'; sleep 0.15
        done ;;
    *) err "No AI provider chosen — pick one in Settings → AI." ;;
    esac ;;
*)
    sed -n '4,8p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
