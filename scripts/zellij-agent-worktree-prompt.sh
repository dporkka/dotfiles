#!/usr/bin/env bash
# =============================================================================
# zellij-agent-worktree-prompt.sh — interactive wrapper for zellij-agent-worktree.sh
#
# Bound to Alt+W in config/zellij/config.kdl. Prompts for a branch, base, agent,
# and optional prompt, then launches an isolated Zellij agent in a git worktree.
# =============================================================================
set -euo pipefail

read -rp "Branch name: " branch
[[ -n "$branch" ]] || { echo "branch name required" >&2; exit 2; }

read -rp "Base [main]: " base
base="${base:-main}"

read -rp "Agent [claude]: " agent
agent="${agent:-claude}"

read -rp "Prompt (optional): " prompt

exec "$HOME/dotfiles/scripts/zellij-agent-worktree.sh" "$branch" --base "$base" --agent "$agent" $prompt
