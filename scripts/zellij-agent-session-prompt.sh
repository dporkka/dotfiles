#!/usr/bin/env bash
# =============================================================================
# zellij-agent-session-prompt.sh — interactive wrapper for zellij-agent-session.sh
#
# Bound to Alt+Shift+a in config/zellij/config.kdl. Prompts for a session name
# and agent, then launches an isolated Zellij agent session.
# =============================================================================
set -euo pipefail

read -rp "Session name: " session
[[ -n "$session" ]] || { echo "session name required" >&2; exit 2; }

read -rp "Agent [claude]: " agent
agent="${agent:-claude}"

read -rp "Extra args: " extra

exec "$HOME/dotfiles/scripts/zellij-agent-session.sh" "$session" "$agent" $extra
