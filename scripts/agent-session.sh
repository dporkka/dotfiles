#!/usr/bin/env bash
# =============================================================================
# agent-session.sh — spawn a named AI agent in a dedicated tmux session
#
# Usage:
#   agent-session.sh <session-name> <agent> [extra-args...]
#   agent-session.sh refactor-auth claude
#   agent-session.sh add-payments aider --model claude-opus-4-5
#
# Design:
# Each agent gets its own tmux session so agents are fully isolated.
# Sessions persist even if you detach — check progress any time.
# =============================================================================

set -euo pipefail

SESSION="${1:?Usage: agent-session.sh <session-name> <agent> [args...]}"
AGENT="${2:-claude}"
shift 2 || true
EXTRA_ARGS="$*"

CWD="${PWD}"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
FULL_SESSION="${SESSION}-${TIMESTAMP}"

echo "Starting agent session: $FULL_SESSION"
echo "Agent: $AGENT $EXTRA_ARGS"
echo "Working directory: $CWD"

if ! command -v tmux &>/dev/null; then
  echo "tmux not found"
  exit 1
fi

# Create isolated session
tmux new-session -d -s "$FULL_SESSION" -c "$CWD"

# Window 1: Agent — run it, then ping when it exits (bell + tmux msg + WSL toast).
# \$HOME stays literal so the pane's own shell expands it at runtime.
tmux rename-window -t "$FULL_SESSION:1" "agent"
tmux send-keys -t "$FULL_SESSION:1" "$AGENT $EXTRA_ARGS; \$HOME/dotfiles/scripts/notify.sh 'Agent finished: $SESSION' 'tmux session $FULL_SESSION'" Enter

# Window 2: Monitoring — watch files the agent is changing
tmux new-window -t "$FULL_SESSION" -n "watch" -c "$CWD"
tmux send-keys -t "$FULL_SESSION:2" "watch -n 2 'git status -sb && echo \"---\" && git diff --stat'" Enter

# Window 3: Review — ready for you to review diffs
tmux new-window -t "$FULL_SESSION" -n "review" -c "$CWD"
tmux send-keys -t "$FULL_SESSION:3" "# Review window — run: git diff, lazygit, nvim" Enter

tmux select-window -t "$FULL_SESSION:1"

echo ""
echo "Session created: $FULL_SESSION"
echo "Commands:"
echo "  Attach:  tmux attach -t $FULL_SESSION"
echo "  List:    tmux ls | grep agent"
echo "  Kill:    tmux kill-session -t $FULL_SESSION"
echo ""

# Attach if we're in a terminal (not being called from script)
if [[ -t 0 ]]; then
  tmux attach -t "$FULL_SESSION"
fi
