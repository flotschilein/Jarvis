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

prompt = os.environ["QUESTION"]
print(json.dumps({
    "model": os.environ.get("OPENAI_MODEL", "gpt-4o-mini"),
    "messages": [{"role": "user", "content": prompt}],
}))
PY
)

    local auth_header
    auth_header=<(printf 'Authorization: Bearer %s\n' "$OPENAI_API_KEY")

    local response
    response=$(curl -sS -X POST "https://api.openai.com/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -H @"$auth_header" \
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
MAX_ERROR_DISPLAY_LENGTH = 500
try:
    data = json.loads(raw)
    choices = data.get("choices") or []
    first_choice = choices[0] if isinstance(choices, list) and len(choices) > 0 else {}
    message = first_choice.get("message") if isinstance(first_choice, dict) else None
    content = message.get("content") if isinstance(message, dict) else None

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
