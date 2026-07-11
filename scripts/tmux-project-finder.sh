#!/bin/bash
# Cached git branch for tmux status-right — avoids forking git every tick.
# Usage: tmux-git-branch.sh <directory>

# Prefer zoxide if available (instant lookup from frecency DB).
# Fall back to find over workspace roots.

SEARCH_ROOTS=("$HOME/dev" "$HOME/workspace" "$HOME/hermes-workspace")

if command -v zoxide &>/dev/null; then
  selected=$(zoxide query -l | fzf --prompt="project> ")
else
  dirs=""
  for root in "${SEARCH_ROOTS[@]}"; do
    [ -d "$root" ] || continue
    dirs+=$(find "$root" -mindepth 1 -maxdepth 3 -type d -name .git 2>/dev/null | sed 's#/\.git$##')
    dirs+=$'\n'
  done
  selected=$(echo "$dirs" | sort -u | grep -v '^$' | fzf --prompt="project> ")
fi

[ -n "$selected" ] || exit 0

# Derive session name: basename, dots/spaces → underscores.
session_name=$(basename "$selected" | tr ' .' '__')
tmux new-session -A -s "$session_name" -c "$selected"
