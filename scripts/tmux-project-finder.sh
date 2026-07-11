#!/bin/bash
# Project finder: fzf over git repos under common workspace roots,
# then attach/create a tmux session for the chosen project.
#
# Called from tmux session-mode 'f' and prefix+f.

SEARCH_ROOTS=("$HOME/dev" "$HOME/workspace" "$HOME/hermes-workspace")

# Collect .git dirs (only if root exists).
dirs=""
for root in "${SEARCH_ROOTS[@]}"; do
  [ -d "$root" ] || continue
  dirs+=$(find "$root" -mindepth 1 -maxdepth 3 -type d -name .git 2>/dev/null | sed 's#/\.git$##')
  dirs+=$'\n'
done

selected=$(echo "$dirs" | sort -u | grep -v '^$' | fzf --prompt="project> ")
[ -n "$selected" ] || exit 0

# Derive session name: basename, dots/spaces → underscores.
session_name=$(basename "$selected" | tr ' .' '__')
tmux new-session -A -s "$session_name" -c "$selected"
