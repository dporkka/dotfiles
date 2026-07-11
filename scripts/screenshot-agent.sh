#!/bin/bash
# screenshot-agent.sh — capture region, copy path to clipboard, optionally display or send to agent.
set -e
ts=$(date +%s)
file="/tmp/screenshot-${ts}.png"

# Capture: grim+slurp (Wayland) preferred, import (ImageMagick) fallback.
if command -v grim &>/dev/null && command -v slurp &>/dev/null; then
  grim -g "$(slurp)" "$file"
elif command -v import &>/dev/null; then
  import "$file"
else
  echo "no screenshot tool found (try: dnf install grim slurp)" >&2; exit 1
fi

# Always copy path to clipboard.
echo -n "$file" | wl-copy

case "${1:-}" in
  --display)
    wezterm imgcat "$file" --width 80% --hold
    ;;
  --send)
    target=$(wezterm cli get-pane-direction Right 2>/dev/null || echo "")
    if [ -n "$target" ]; then
      wezterm cli send-text --pane-id "$target" "$file"$'\n'
    fi
    echo "$file"
    ;;
  *)
    echo "$file"
    ;;
esac
