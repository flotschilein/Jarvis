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

    local max_question_length=8000
    if (( ${#question} > max_question_length )); then
        echo "Question is too long (max ${max_question_length} characters)." >&2
        return 1
    fi

    if [[ -z "$OPENAI_API_KEY" ]]; then
        echo "Please set the OPENAI_API_KEY environment variable." >&2
        return 1
    fi

    local payload
    payload=$(QUESTION="$question" python3 - <<'PY'
import json
import os
import sys

prompt = os.environ.get("QUESTION")
if not prompt:
    raise KeyError("QUESTION")
print(json.dumps({
    "model": os.environ.get("OPENAI_MODEL", "gpt-4o-mini"),
    "messages": [{"role": "user", "content": prompt}],
}))
PY
)

    local auth_header_file
    auth_header_file=$(mktemp) || {
        echo "Failed to create a temporary file for the auth header." >&2
        return 1
    }
    chmod 600 "$auth_header_file"
    printf 'Authorization: Bearer %s\n' "$OPENAI_API_KEY" >"$auth_header_file"

    local response
    response=$(curl -sS -X POST "https://api.openai.com/v1/chat/completions" \
        --connect-timeout 10 --max-time 60 \
        -H "Content-Type: application/json" \
        -H @"$auth_header_file" \
        -d "$payload")
    local curl_status=$?
    rm -f "$auth_header_file"
    if ((curl_status != 0)); then
        echo "Failed to reach the OpenAI API (exit code $curl_status)." >&2
        return $curl_status
    fi

    echo "$response" | python3 - <<'PY'
import json
import sys

raw = sys.stdin.read()
MAX_ERROR_DISPLAY_LENGTH = 500
try:
    data = json.loads(raw)
    if not isinstance(data, dict):
        raise ValueError("response is not an object")

    choices = data.get("choices")
    if not isinstance(choices, list) or not choices:
        raise ValueError("choices list missing or empty")

    first_choice = choices[0]
    message = first_choice.get("message") if isinstance(first_choice, dict) else None
    if not isinstance(message, dict):
        raise ValueError("message is missing")

    content = message.get("content")

    if content:
        print(content.strip())
    else:
        raise KeyError("content")
except Exception as exc:
    sys.stderr.write("Unexpected OpenAI response: {}\n".format(exc))
    if raw:
        display = raw if len(raw) <= MAX_ERROR_DISPLAY_LENGTH else raw[:MAX_ERROR_DISPLAY_LENGTH] + "...(truncated)"
        sys.stderr.write(display + "\n")
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
