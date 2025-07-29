#!/bin/bash
osascript -e 'tell application "System Events" to tell appearance preferences to set dark mode to true'
osascript -e 'tell application "Google Chrome" to quit'
osascript -e 'tell application "Visual Studio Code" to quit'
sleep 3
urls=(
  "https://www.google.com"
  "https://github.com"
  "https://chat.openai.com"
  "https://www.youtube.com"
  "https://chat.deepseek.com/"
)

code_folder="path to code folder"
chrome_path="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
vscode_path="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"

"$chrome_path" --new-window "${urls[@]}" >/dev/null 2>&1 &
sleep 3
"$vscode_path" "$core_folder" >/dev/null 2>&1 &

echo "that's it, ready to go!"

