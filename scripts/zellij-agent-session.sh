#!/usr/bin/env bash
# =============================================================================
# zellij-agent-session.sh — spawn a named AI agent in a dedicated Zellij session
#
# Usage:
#   zellij-agent-session.sh <session-name> <agent> [extra-args...]
#   zellij-agent-session.sh refactor-auth claude
#   zellij-agent-session.sh add-payments aider --model claude-opus-4-5
#
# Design:
# Each agent gets its own Zellij session so agents are fully isolated.
# Sessions persist even if you detach — check progress any time.
# The agent command is passed to the shared agent.kdl layout via ZELLIJ_AGENT_CMD.
# The session is registered in agent-registry.sh so dashboards can see it.
# =============================================================================

set -euo pipefail

SESSION="${1:?Usage: zellij-agent-session.sh <session-name> <agent> [args...]}"
AGENT="${2:-claude}"
shift 2 || true
EXTRA_ARGS="$*"

CWD="${PWD}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
FULL_SESSION="${SESSION}-${TIMESTAMP}"

# Export for the shared agent.kdl layout so the agent pane runs the right CLI.
# Do NOT export ZELLIJ_SESSION_NAME here: zellij sets it inside panes and
# pre-setting it confuses `zellij attach -b <name>`.
export ZELLIJ_AGENT_CMD="${AGENT}${EXTRA_ARGS:+ }${EXTRA_ARGS}"

echo "Starting agent session: $FULL_SESSION"
echo "Agent: $ZELLIJ_AGENT_CMD"
echo "Working directory: $CWD"

LAYOUT_DIR="${DOTS:-$HOME/dotfiles}/config/zellij/layouts"
LAYOUT="${LAYOUT_DIR}/agent.kdl"

if [[ ! -f "$LAYOUT" ]]; then
  echo "layout not found: $LAYOUT"
  exit 1
fi

if ! command -v zellij &>/dev/null; then
  echo "zellij not found"
  exit 1
fi

# Register with the unified agent registry so cross-multiplexer dashboards can
# find this session. worktree/branch are best-effort; base is not meaningful here.
CURRENT_BRANCH=""
if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  CURRENT_BRANCH="$(git branch --show-current 2>/dev/null || true)"
fi
"$HOME/dotfiles/scripts/agent-registry.sh" register "$FULL_SESSION" zellij \
  worktree="$CWD" \
  branch="${CURRENT_BRANCH:-}" \
  base="" \
  agent_cmd="$ZELLIJ_AGENT_CMD" \
  agent="$AGENT" \
  prompt="$EXTRA_ARGS" \
  pid="$$" 2>/dev/null || true

# Create the session in the background from the current directory.
# `attach -b` creates a detached session; the layout defines the tabs/panes.
cd "$CWD"
zellij --layout "$LAYOUT" attach -b "$FULL_SESSION"

echo ""
echo "Session created: $FULL_SESSION"
echo "Commands:"
echo "  Attach:  zellij attach $FULL_SESSION"
echo "  List:    zellij list-sessions"
echo "  Kill:    zellij kill-session $FULL_SESSION"
echo ""

# Attach if we're in a terminal. From inside zellij, switch sessions instead
# of nesting; from outside, attach normally.
if [[ -t 0 ]]; then
  if [[ -n "${ZELLIJ:-}" ]]; then
    zellij action switch-session "$FULL_SESSION"
  else
    zellij attach "$FULL_SESSION"
  fi
else
  echo "Not running in a terminal; start zellij interactively to attach to $FULL_SESSION"
fi
