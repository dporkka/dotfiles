#!/usr/bin/env bash
# send-to-all-panes.sh — send a command to every pane in the current tmux window
# Usage: send-to-all-panes.sh "command to run"
set -euo pipefail

cmd="${1:-}"
[ -z "$cmd" ] && exit 0

for pane in $(tmux list-panes -F '#{pane_id}'); do
  tmux send-keys -t "$pane" "$cmd" Enter
done
