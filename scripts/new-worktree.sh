#!/usr/bin/env bash
# =============================================================================
# new-worktree.sh — create a git worktree for parallel AI agent work
#
# Usage:
#   new-worktree.sh <branch-name> [base-branch]
#   new-worktree.sh feat/payment-flow main
#
# What it does:
# 1. Creates a worktree at ../$(repo-name)-$(branch-slug)
# 2. Installs node_modules if package.json exists
# 3. Opens a tmux session named after the branch with nvim + terminal
# =============================================================================

set -euo pipefail

BRANCH="${1:?Usage: new-worktree.sh <branch-name> [base-branch]}"
BASE="${2:-main}"

REPO_ROOT=$(git rev-parse --show-toplevel 2>/dev/null \
  || { echo "Error: not in a git repository"; exit 1; })
REPO_NAME=$(basename "$REPO_ROOT")

# Sanitize branch name for directory/session use
SLUG="${BRANCH//\//-}"
WORKTREE_PATH="$(dirname "$REPO_ROOT")/${REPO_NAME}-${SLUG}"
SESSION_NAME="${REPO_NAME}-${SLUG}"

echo "Creating worktree: $WORKTREE_PATH"
echo "Branch: $BRANCH (from $BASE)"

# Create worktree (branch may already exist if resuming)
if git worktree list | grep -q "$WORKTREE_PATH"; then
  echo "Worktree already exists at $WORKTREE_PATH"
else
  git worktree add "$WORKTREE_PATH" -b "$BRANCH" "$BASE" 2>/dev/null \
    || git worktree add "$WORKTREE_PATH" "$BRANCH"
fi

cd "$WORKTREE_PATH"

# Install dependencies if needed
if [[ -f "package.json" ]]; then
  echo "Installing dependencies..."
  if command -v pnpm &>/dev/null; then
    pnpm install --frozen-lockfile 2>/dev/null \
      || pnpm install
  elif command -v npm &>/dev/null; then
    npm install
  fi
fi

# Create tmux session with productive layout
if command -v tmux &>/dev/null; then
  if tmux has-session -t "$SESSION_NAME" 2>/dev/null; then
    echo "Attaching to existing session: $SESSION_NAME"
    tmux attach -t "$SESSION_NAME"
    exit 0
  fi

  echo "Creating tmux session: $SESSION_NAME"

  # Session with 2 windows: editor and agent
  tmux new-session -d -s "$SESSION_NAME" -c "$WORKTREE_PATH"

  # Window 1: Editor (nvim) + terminal split
  tmux rename-window -t "$SESSION_NAME:1" "editor"
  tmux split-window -t "$SESSION_NAME:1" -h -p 30 -c "$WORKTREE_PATH"
  tmux select-pane -t "$SESSION_NAME:1.1"  # left pane = nvim
  tmux send-keys -t "$SESSION_NAME:1.1" "nvim ." Enter

  # Window 2: AI agent
  tmux new-window -t "$SESSION_NAME" -n "agent" -c "$WORKTREE_PATH"
  tmux send-keys -t "$SESSION_NAME:2" "# AI agent window — run: claude, aider, etc." Enter

  # Window 3: Dev server / tests
  tmux new-window -t "$SESSION_NAME" -n "dev" -c "$WORKTREE_PATH"
  tmux send-keys -t "$SESSION_NAME:3" "# Dev server — run: pnpm dev, pnpm test, etc." Enter

  tmux select-window -t "$SESSION_NAME:1"
  tmux attach -t "$SESSION_NAME"
else
  cd "$WORKTREE_PATH"
  echo "Worktree ready at: $WORKTREE_PATH"
  echo "tmux not available — cd to worktree manually"
fi
