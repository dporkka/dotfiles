#!/usr/bin/env bash
# =============================================================================
# zellij-agent-dashboard.sh — compatibility wrapper for the unified dashboard.
#
# config/zellij/config.kdl still binds Alt+d and tmux-mode "a" to this script.
# It delegates to agent-dashboard.sh, which lists every agent in the registry
# (tmux + Zellij) and jumps to the selected one.
# =============================================================================
set -euo pipefail

exec "$HOME/dotfiles/scripts/agent-dashboard.sh" "$@"
