#!/usr/bin/env bash
# =============================================================================
# tmux-template.sh — apply a named session layout template.
#
# Templates live in ~/.config/tmux/templates/<name>.json and define:
#   { "windows": [ { "name": "...", "cwd": ".", "panes": [
#       { "cmd": "nvim .", "split": null },
#       { "cmd": "kimi", "split": "vertical", "pct": 40 }
#     ] } ] }
#
# Usage: tmux-template.sh <template-name> [project-dir]
# =============================================================================
set -euo pipefail

TEMPLATE_NAME="${1:-}"
PROJECT_DIR="${2:-$(pwd)}"

[[ -n "$TEMPLATE_NAME" ]] || { echo "Usage: tmux-template.sh <template> [dir]" >&2; exit 2; }

TEMPLATES_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/tmux/templates"
TEMPLATE_FILE="$TEMPLATES_DIR/${TEMPLATE_NAME}.json"

[[ -f "$TEMPLATE_FILE" ]] || { echo "Template not found: $TEMPLATE_FILE" >&2; exit 1; }

command -v jq >/dev/null 2>&1 || { echo "jq required: https://stedolan.github.io/jq" >&2; exit 1; }
command -v tmux >/dev/null 2>&1 || { echo "tmux required" >&2; exit 1; }

PROJECT_NAME="$(basename "$PROJECT_DIR")"
SESSION="${TEMPLATE_NAME}-${PROJECT_NAME}"

# Kill existing session with this name so we get a clean layout.
tmux kill-session -t "$SESSION" 2>/dev/null || true

# Create session with the first window.
WINDOW_COUNT=$(jq '.windows | length' "$TEMPLATE_FILE")

for ((w=0; w<WINDOW_COUNT; w++)); do
  WIN_NAME=$(jq -r ".windows[$w].name" "$TEMPLATE_FILE")
  WIN_CWD_REL=$(jq -r ".windows[$w].cwd // \".\"" "$TEMPLATE_FILE")
  WIN_CWD="$PROJECT_DIR/$WIN_CWD_REL"

  if [[ $w -eq 0 ]]; then
    tmux new-session -d -s "$SESSION" -n "$WIN_NAME" -c "$WIN_CWD"
  else
    tmux new-window -t "$SESSION" -n "$WIN_NAME" -c "$WIN_CWD"
  fi

  PANE_COUNT=$(jq ".windows[$w].panes | length" "$TEMPLATE_FILE")
  TARGET="$SESSION:$((w+1))"

  for ((p=0; p<PANE_COUNT; p++)); do
    PANE_CMD=$(jq -r ".windows[$w].panes[$p].cmd // \"\"" "$TEMPLATE_FILE")
    PANE_SPLIT=$(jq -r ".windows[$w].panes[$p].split // \"\"" "$TEMPLATE_FILE")
    PANE_PCT=$(jq -r ".windows[$w].panes[$p].pct // 50" "$TEMPLATE_FILE")

    if [[ $p -gt 0 && -n "$PANE_SPLIT" ]]; then
      if [[ "$PANE_SPLIT" == "vertical" ]]; then
        tmux split-window -t "$TARGET" -h -p "$PANE_PCT" -c "$WIN_CWD"
      else
        tmux split-window -t "$TARGET" -v -p "$PANE_PCT" -c "$WIN_CWD"
      fi
    fi

    if [[ -n "$PANE_CMD" ]]; then
      tmux send-keys -t "$TARGET" "$PANE_CMD" Enter
    fi
  done

  # Select first pane of each window.
  tmux select-pane -t "$TARGET.0"
done

# Attach.
if [[ -n "${TMUX:-}" ]]; then
  tmux switch-client -t "$SESSION"
else
  tmux attach-session -t "$SESSION"
fi
