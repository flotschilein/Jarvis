#!/bin/bash

urls=(
    "https://github.com"
    "https://chat.openai.com"
    "https://www.youtube.com"
    "https://chat.deepseek.com/"
)

code_folder="/homeofcode"
vscode_cmd="code"
chrome_cmd="flatpak run com.google.Chrome"

ask_openai() {
    local question="$*"

    if [[ -z "$question" ]]; then
        echo "Usage: $0 --ask \"your question\"" >&2
        return 1
    fi

    if [[ -z "$OPENAI_API_KEY" ]]; then
        echo "Please set the OPENAI_API_KEY environment variable." >&2
        return 1
    fi

    local payload
    payload=$(python3 - "$question" <<'PY'
import json
import os
import sys

prompt = sys.argv[1]
print(json.dumps({
    "model": os.environ.get("OPENAI_MODEL", "gpt-4o-mini"),
    "messages": [{"role": "user", "content": prompt}],
}))
PY
)

    local response
    response=$(curl -sS -X POST "https://api.openai.com/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H "Authorization: Bearer $OPENAI_API_KEY" \
        -d "$payload")
    local curl_status=$?
    if ((curl_status != 0)); then
        echo "Failed to reach the OpenAI API (exit code $curl_status)." >&2
        return $curl_status
    fi

    echo "$response" | python3 - <<'PY'
import json
import sys

raw = sys.stdin.read()
try:
    data = json.loads(raw)
    choices = data.get("choices") or []
    first_choice = choices[0] if choices else {}
    message = first_choice.get("message") if isinstance(first_choice, dict) else None
    content = message.get("content") if isinstance(message, dict) else None

    if content:
        print(content.strip())
    else:
        raise KeyError("content")
except Exception as exc:
    sys.stderr.write("Unexpected OpenAI response: {}\n".format(exc))
    sys.stdout.write(raw)
    sys.exit(1)
PY
}

if [[ "$1" == "--ask" || "$1" == "-q" ]]; then
    shift
    ask_openai "$@"
    exit $?
fi

$chrome_cmd --new-window "${urls[@]}" >/dev/null 2>&1 &
$vscode_cmd "$code_folder" >/dev/null 2>&1 &
echo "that's it, ready to go!"
