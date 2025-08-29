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

$chrome_cmd --new-window "${urls[@]}" >/dev/null 2>&1 &
$vscode_cmd "$code_folder" >/dev/null 2>&1 &
echo "that's it, ready to go!"