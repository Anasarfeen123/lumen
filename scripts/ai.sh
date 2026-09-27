#!/bin/sh
# ai.sh — Lumen Halo's only connection to a model.
#
#   ai.sh ask <request.json>     stream an answer as JSON lines: {"t":"text"} … {"s":{n,ms}} or {"e":"error"}
#   ai.sh capture <out.jpg>      screenshot of the focused monitor, scaled for a model
#   ai.sh set-key <provider>     read an API key from stdin, store it (mode 600)
#   ai.sh forget-key <provider>  delete a stored key
#   ai.sh set-custom <url> <model>   an OpenAI-compatible server (LM Studio, llama.cpp, vLLM, LocalAI, Jan…)
#   ai.sh models <provider>      the provider's models, as a JSON array of ids (asks the provider)
#   ai.sh status                 which providers are usable; local models, sizes, which read images
#   ai.sh warm <model>           load a local model now, so the first answer is quick
#   ai.sh pull <model>           download a local model from Ollama's registry: {"p":0-100,"st":"…"} lines
#   ai.sh rm <model>             delete a local model
#
# Providers: ollama (this computer) · anthropic (Claude) · openai · gemini · openrouter ·
# groq · mistral · custom (any OpenAI-compatible endpoint). All but Anthropic and
# Ollama go through the OpenAI Chat Completions format.
#
# request.json: { provider, model, system, messages: [{ role, text, image?: "/path.jpg" }] }
# API keys live in ~/.local/state/lumen/ai/<provider>.key (mode 600) and reach
# curl through a header file on stdin, never the command line or a log.
# Images and long texts go through files (jq --slurpfile/--rawfile): command-line
# arguments are limited to 128 KiB, which a single screenshot exceeds.
# Model downloads (pull) come only from the registry Ollama itself uses.
set -u
DIR=${XDG_STATE_HOME:-$HOME/.local/state}/lumen/ai
OLLAMA=${LUMEN_OLLAMA_URL:-http://127.0.0.1:11434}
TMP=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/lumen-ai.XXXXXX") || exit 1
chmod 700 "$TMP"
trap 'rm -rf "$TMP"' EXIT
err() { jq -cn --arg e "$1" '{e:$e}'; exit 1; }

# Where each OpenAI-compatible provider lives
base_url() {
    # Tests only: LUMEN_AI_URL_<PROVIDER> points a provider at a local mock server
    o=$(printenv "LUMEN_AI_URL_$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')" 2>/dev/null) && [ -n "$o" ] && { echo "$o"; return; }
    case $1 in
        openai)     echo https://api.openai.com/v1 ;;
        gemini)     echo https://generativelanguage.googleapis.com/v1beta/openai ;;
        openrouter) echo https://openrouter.ai/api/v1 ;;
        groq)       echo https://api.groq.com/openai/v1 ;;
        mistral)    echo https://api.mistral.ai/v1 ;;
        custom)     jq -r '.url // empty' "$DIR/custom.json" 2>/dev/null | sed 's:/*$::' ;;
    esac
}
label() {
    case $1 in openai) echo OpenAI ;; gemini) echo Gemini ;; openrouter) echo OpenRouter ;; groq) echo Groq ;;
               mistral) echo Mistral ;; custom) echo "your server" ;; anthropic) echo Claude ;; ollama) echo Ollama ;; *) echo "$1" ;; esac
}
key_file() { printf '%s/%s.key' "$DIR" "$1"; }
known_provider() { case $1 in anthropic|openai|gemini|openrouter|groq|mistral|custom) return 0 ;; *) return 1 ;; esac; }
# The auth header for a provider, written to a private file (never an argument)
auth_headers() {
    k=$(key_file "$1"); : > "$TMP/h"
    # a provider with no key yet is a normal state, not an error: do not cat a
    # file that is not there, and do not shout about it on stderr
    if [ "$1" = anthropic ] && [ -s "$k" ]; then
        printf 'x-api-key: %s\nanthropic-version: 2023-06-01\n' "$(cat "$k")" > "$TMP/h"
    elif [ -s "$k" ]; then
        printf 'Authorization: Bearer %s\n' "$(cat "$k")" > "$TMP/h"
    fi
    [ "$1" = openrouter ] && printf 'HTTP-Referer: https://github.com/Anasarfeen123/lumen\nX-Title: Lumen Halo\n' >> "$TMP/h"
    printf 'content-type: application/json\n' >> "$TMP/h"
}

# Every image in the request, base64'd into a JSON object {path: base64} on disk
images_json() {
    : > "$TMP/imgs.jsonl"
    jq -r '[.messages[].image // empty] | unique | .[]' "$1" | while IFS= read -r f; do
        [ -f "$f" ] || continue
        src=$f
        # Keep what goes to a model small (big images are slow and some APIs refuse them)
        if [ "$(stat -c %s "$f")" -gt 1500000 ]; then
            magick "${f}[0]" -resize '1568x1568>' -quality 82 "$TMP/small.jpg" 2>/dev/null && src=$TMP/small.jpg
        fi
        base64 -w0 "$src" > "$TMP/b64"
        jq -cn --arg f "$f" --rawfile d "$TMP/b64" '{($f): $d}' >> "$TMP/imgs.jsonl"
    done
    jq -s 'add // {}' "$TMP/imgs.jsonl" > "$TMP/imgs.json"
}

# Stream a response through a filter; on failure say what happened
#   stream <curl args…>  (the jq filter for data lines is in $FILTER)
stream() {
    : > "$TMP/raw"; : > "$TMP/out"
    { curl -sS -N --connect-timeout 6 "$@" 2>"$TMP/curlerr"; echo $? > "$TMP/rc"; } |
        tee "$TMP/raw" | sed -un -e '/^data: /{s/^data: //p;d}' -e '/^{/p' |
        jq -c --unbuffered "$FILTER" 2>/dev/null | tee "$TMP/out"
    rc=$(cat "$TMP/rc" 2>/dev/null || echo 1)
    grep -q '"e":' "$TMP/out" && return 0                   # the provider's own error, already said
    if grep -q '"t":' "$TMP/out"; then                       # an answer came; maybe cut short
        [ "$rc" = 28 ] && jq -cn --arg e "$PROVIDER_LABEL stopped answering (took too long)." '{e:$e}'
        return 0
    fi
    # Nothing came: say why. Error bodies are often plain (pretty-printed) JSON.
    msg=$(jq -rs '[.[] | (.error.message? // .error? // .message? // empty) | tostring][0] // empty' "$TMP/raw" 2>/dev/null | head -n 1)
    case $rc in
        6|7) msg="Couldn't reach $PROVIDER_LABEL. Check your connection, or that the server is running." ;;
        28)  msg="$PROVIDER_LABEL took too long to answer. A large model or an image can be slow on this computer — try again, or pick a smaller model." ;;
        0)   [ -n "$msg" ] || msg="$PROVIDER_LABEL sent an empty answer." ;;
        *)   [ -n "$msg" ] || msg="Something went wrong talking to $PROVIDER_LABEL ($(head -c 160 "$TMP/curlerr"))." ;;
    esac
    jq -cn --arg e "$msg" '{e:$e}'
}

case ${1:-} in
set-key)
    p=${2:-}; known_provider "$p" || { echo "usage: ai.sh set-key anthropic|openai|gemini|openrouter|groq|mistral|custom" >&2; exit 2; }
    mkdir -p "$DIR"; chmod 700 "$DIR"
    umask 077
    IFS= read -r k || true
    k=$(printf '%s' "$k" | tr -d '[:space:]')
    ok=1
    case $p in
        anthropic)  case $k in sk-ant-*) ;; *) ok=0; want="sk-ant-…" ;; esac ;;
        openrouter) case $k in sk-or-*) ;; *) ok=0; want="sk-or-…" ;; esac ;;
        openai)     case $k in sk-*) ;; *) ok=0; want="sk-…" ;; esac ;;
        groq)       case $k in gsk_*) ;; *) ok=0; want="gsk_…" ;; esac ;;
        gemini)     case $k in AIza*) ;; *) ok=0; want="AIza…" ;; esac ;;
        mistral)    [ "${#k}" -ge 20 ] || { ok=0; want="a 32-character key"; } ;;
        custom)     [ -n "$k" ] || { ok=0; want="a key"; } ;;
    esac
    [ $ok = 1 ] || { echo "That doesn't look like a $(label "$p") key ($want)" >&2; exit 1; }
    printf '%s' "$k" > "$(key_file "$p")"; echo saved ;;
forget-key)
    known_provider "${2:-}" || exit 2
    rm -f "$(key_file "$2")"; echo forgotten ;;
set-custom)
    url=${2:-}; model=${3:-}
    case $url in http://*|https://*) ;; *) echo "The address must start with http:// or https://" >&2; exit 1 ;; esac
    mkdir -p "$DIR"; chmod 700 "$DIR"; umask 077
    jq -cn --arg u "$url" --arg m "$model" '{url:$u, model:$m}' > "$DIR/custom.json"; echo saved ;;
models)
    p=${2:-}
    # Always a JSON array, even when the provider is unreachable or has no key
    # yet: the caller parses this, and a silent empty stdout is worse than an
    # empty list. curl's own errors are dropped — the UI already says "no key
    # yet" or "could not reach it" from the status, and stderr here would only
    # print under the settings window.
    #
    # jq reads with -Rs (slurp the body as one string) because plain jq on
    # empty input prints NOTHING and still exits 0, so the `|| echo '[]'`
    # below would never run. fromjson? turns a body that is not JSON — an
    # HTML error page, nothing at all — into {} and the answer stays an array.
    case $p in
    ollama) curl -fsS --max-time 3 "$OLLAMA/api/tags" 2>/dev/null | jq -Rsc '((. | fromjson?) // {}) | [.models[]?.name]' || echo '[]' ;;
    anthropic)
        auth_headers anthropic
        curl -fsS --max-time 8 -H @"$TMP/h" https://api.anthropic.com/v1/models 2>/dev/null |
            jq -Rsc '((. | fromjson?) // {}) | [.data[]?.id]' || echo '[]' ;;
    openai|gemini|openrouter|groq|mistral|custom)
        b=$(base_url "$p"); [ -n "$b" ] || { echo '[]'; exit 0; }
        auth_headers "$p"
        curl -fsS --max-time 10 -H @"$TMP/h" "$b/models" 2>/dev/null |
            jq -Rsc '((. | fromjson?) // {}) | [(.data // .models // [])[] | (.id // .name) | sub("^models/"; "")] | sort' || echo '[]' ;;
    *) echo '[]' ;;
    esac ;;
status)
    o=no; curl -fsS --max-time 1 "$OLLAMA/api/tags" >/dev/null 2>&1 && o=yes
    tags='{"models":[]}'; loaded='[]'
    if [ $o = yes ]; then
        tags=$(curl -fsS --max-time 2 "$OLLAMA/api/tags" || echo '{"models":[]}')
        loaded=$(curl -fsS --max-time 2 "$OLLAMA/api/ps" | jq -c '[.models[].name]' 2>/dev/null || echo '[]')
    fi
    keys="{}"
    for p in anthropic openai gemini openrouter groq mistral custom; do
        [ -s "$(key_file "$p")" ] && keys=$(printf '%s' "$keys" | jq -c --arg p "$p" '.[$p] = true')
    done
    custom=$(cat "$DIR/custom.json" 2>/dev/null || echo '{}')
    # ollamaInfo: size in bytes, parameter count, and whether it reads images
    printf '%s' "$tags" | jq -c --arg o "$o" --argjson l "$loaded" --argjson k "$keys" --argjson c "$custom" '{
        anthropic: ($k.anthropic // false), keys: $k, custom: $c,
        ollama: ($o == "yes"), ollamaModels: [.models[].name], loaded: $l,
        ollamaInfo: [.models[] | { name, size, params: (.details.parameter_size // ""),
            vision: (((.details.families // []) | any(. == "clip" or . == "mllama")) or ((.details.family // "") | test("gemma3|llava|qwen2.5vl|minicpm"))) }] }' ;;
warm)
    m=${2:?}
    jq -cn --arg m "$m" '{model:$m, keep_alive:"15m"}' |
      curl -fsS --max-time 120 -H 'content-type: application/json' --data-binary @- "$OLLAMA/api/generate" >/dev/null 2>&1 || true ;;
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
    PROVIDER_LABEL=$(label "$provider")
    has_image=$(jq -r '[.messages[].image // empty] | length > 0' "$req")
    body=$TMP/body.json
    case $provider in
    ollama)
        images_json "$req"
        jq -c --slurpfile imgs "$TMP/imgs.json" '
          {model, stream:true, keep_alive:"15m",
           options:{num_ctx:(if ([.messages[].text] | add | length) > 9000 then 8192 else 4096 end)},
           messages:([{role:"system", content:.system}] + [.messages[] | {role, content:.text} + (if .image then {images:[$imgs[0][.image]]} else {} end)])}' \
          "$req" > "$body"
        # Images on a model that runs partly on the CPU can take minutes
        t=300; [ "$has_image" = true ] && t=900
        FILTER='if .error then {e:.error}
                elif .done then {s:{n:(.eval_count // 0), ms:((.eval_duration // 0) / 1000000 | floor)}}
                else {t:(.message.content // "")} end'
        curl -fsS --max-time 1 "$OLLAMA/api/tags" >/dev/null 2>&1 || err "Ollama isn't running on this computer (systemctl start ollama)."
        stream --max-time "$t" -H 'content-type: application/json' --data-binary @"$body" "$OLLAMA/api/chat" ;;
    anthropic)
        [ -s "$(key_file anthropic)" ] || err "No Anthropic API key yet — add one in Settings → Halo."
        images_json "$req"
        jq -c --slurpfile imgs "$TMP/imgs.json" '
          def content: if .image then [ {type:"image", source:{type:"base64", media_type:"image/jpeg", data:$imgs[0][.image]}}, {type:"text", text:.text} ] else .text end;
          {model, max_tokens:4096, stream:true, system, messages:[.messages[] | {role, content:content}]}' \
          "$req" > "$body"
        auth_headers anthropic
        FILTER='if .type=="content_block_delta" then {t:(.delta.text // "")}
                elif .type=="message_delta" and .usage then {s:{n:(.usage.output_tokens // 0), ms:0}}
                elif .type=="error" then {e:.error.message} else empty end'
        stream --max-time 300 -H @"$TMP/h" --data-binary @"$body" "${LUMEN_AI_URL_ANTHROPIC:-https://api.anthropic.com/v1}/messages" ;;
    openai|gemini|openrouter|groq|mistral|custom)
        b=$(base_url "$provider")
        [ -n "$b" ] || err "Set your server's address first — Settings → Halo → Custom."
        [ "$provider" = custom ] || [ -s "$(key_file "$provider")" ] || err "No $PROVIDER_LABEL API key yet — add one in Settings → Halo."
        images_json "$req"
        jq -c --slurpfile imgs "$TMP/imgs.json" '
          def content: if .image then [ {type:"text", text:.text}, {type:"image_url", image_url:{url:("data:image/jpeg;base64," + $imgs[0][.image])}} ] else .text end;
          {model, stream:true, stream_options:{include_usage:true},
           messages:([{role:"system", content:.system}] + [.messages[] | {role, content:content}])}' \
          "$req" > "$body"
        # Some servers reject stream_options; llama.cpp and LM Studio accept it
        auth_headers "$provider"
        FILTER='if .error then {e:(.error.message // .error | tostring)}
                elif (.choices // []) | length > 0 then ((.choices[0].delta.content // "") as $c | if $c != "" then {t:$c} else empty end)
                elif .usage then {s:{n:(.usage.completion_tokens // 0), ms:0}} else empty end'
        t=300; [ "$has_image" = true ] && t=600
        stream --max-time "$t" -H @"$TMP/h" --data-binary @"$body" "$b/chat/completions" ;;
    mock)   # dev/showcase only: a canned, streamed answer (no network)
        for chunk in "That error means **port 8080 is already taken**, most likely by an earlier copy of your dev server that's still running.\n\n" \
                     "**See what's using it:**\n\n\`\`\`sh\nss -ltnp 'sport = :8080'\n\`\`\`\n\n" \
                     "Then either stop that process, or start yours on another port:\n\n\`\`\`sh\nPORT=8081 npm run dev\n\`\`\`\n\n" \
                     "Nothing here is destructive; check what the process is before you stop it."; do
            t=$(printf '%bx' "$chunk"); jq -cn --arg t "${t%x}" '{t:$t}'; sleep 0.12
        done
        jq -cn '{s:{n:212, ms:4100}}' ;;
    mocklong)   # dev only: ~400 words streamed at local-model speed (UI performance tests)
        i=0
        while [ $i -lt 420 ]; do
            case $((i % 60)) in 0) w="\n\n## Part $((i / 60 + 1))\n\n" ;; 30) w="\n\n- a **bold** point with \`code\` " ;; *) w="word$i " ;; esac
            t=$(printf '%bx' "$w"); jq -cn --arg t "${t%x}" '{t:$t}'
            i=$((i + 1)); sleep 0.014
        done
        jq -cn '{s:{n:420, ms:6000}}' ;;
    *) err "No AI provider chosen — pick one in Settings → Halo." ;;
    esac ;;
*)
    sed -n '4,15p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2 ;;
esac
