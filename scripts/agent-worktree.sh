#!/usr/bin/env bash
# =============================================================================
# agent-worktree.sh — spin up an isolated AI agent in its own git worktree.
#
# One command: git worktree -> deps -> tmux session -> launch the agent.
# Each agent gets its own branch + working directory, so parallel agents never
# collide on files. The session is tagged @is_agent so it appears in the agent
# dashboard (prefix a), and Claude Code hooks (agent-hook.sh) light up its
# window state. This is the flow new-worktree.sh + agent-session.sh implied but
# never joined — use new-worktree.sh when you want a worktree WITHOUT an agent.
#
# Usage:
#   agent-worktree.sh <branch> [initial prompt words...]
#     --base  <branch>   base to branch from   (default: main)
#     --agent <cmd>      agent command to run   (default: claude)
#
# Examples:
#   agent-worktree.sh feat/payments
#   agent-worktree.sh fix/login --base develop add MFA to the login form
#   agent-worktree.sh chore/types --agent aider
# =============================================================================
set -euo pipefail

BASE="main"
AGENT="claude"
BRANCH=""
PROMPT_WORDS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --base)  BASE="${2:?--base needs a value}"; shift 2 ;;
    --agent) AGENT="${2:?--agent needs a value}"; shift 2 ;;
    --)      shift; PROMPT_WORDS+=("$@"); break ;;
    -*)      echo "unknown flag: $1" >&2; exit 2 ;;
    *)       if [[ -z "$BRANCH" ]]; then BRANCH="$1"; else PROMPT_WORDS+=("$1"); fi; shift ;;
  esac
done

[[ -n "$BRANCH" ]] \
  || { echo "Usage: agent-worktree.sh <branch> [prompt...] [--base b] [--agent cmd]" >&2; exit 2; }
PROMPT="${PROMPT_WORDS[*]:-}"

command -v tmux >/dev/null 2>&1 || { echo "tmux required" >&2; exit 1; }
REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || { echo "not in a git repository" >&2; exit 1; }

REPO_NAME="$(basename "$REPO_ROOT")"
SLUG="${BRANCH//\//-}"
WORKTREE_PATH="$(dirname "$REPO_ROOT")/${REPO_NAME}-${SLUG}"
SESSION="${REPO_NAME}-${SLUG}"

# 1. Worktree (resume if it already exists)
if git -C "$REPO_ROOT" worktree list | grep -qF "$WORKTREE_PATH"; then
  echo "Worktree exists: $WORKTREE_PATH"
else
  echo "Creating worktree $WORKTREE_PATH (branch $BRANCH from $BASE)"
  git -C "$REPO_ROOT" worktree add "$WORKTREE_PATH" -b "$BRANCH" "$BASE" 2>/dev/null \
    || git -C "$REPO_ROOT" worktree add "$WORKTREE_PATH" "$BRANCH"
fi

# 2. Deps — best effort, backgrounded so the session opens immediately
if [[ -f "$WORKTREE_PATH/package.json" ]]; then
  if command -v pnpm >/dev/null 2>&1; then
    (cd "$WORKTREE_PATH" && pnpm install >/dev/null 2>&1 &) || true
  elif command -v npm >/dev/null 2>&1; then
    (cd "$WORKTREE_PATH" && npm install >/dev/null 2>&1 &) || true
  fi
fi

# 3. Session (idempotent)
if ! tmux has-session -t "$SESSION" 2>/dev/null; then
  tmux new-session -d -s "$SESSION" -c "$WORKTREE_PATH"
  tmux set-option -t "$SESSION" @is_agent 1

  # Window 1: agent. monitor-silence is a fallback "went quiet" signal for
  # agents without Claude Code hooks (e.g. aider); Claude sets @agent_state.
  tmux rename-window -t "$SESSION:1" "agent"
  tmux set-window-option -t "$SESSION:1" monitor-silence 20
  if [[ -n "$PROMPT" ]]; then
    tmux send-keys -t "$SESSION:1" "$AGENT $(printf '%q' "$PROMPT")" Enter
  else
    tmux send-keys -t "$SESSION:1" "$AGENT" Enter
  fi

  # Window 2: editor
  tmux new-window -t "$SESSION" -n "editor" -c "$WORKTREE_PATH"
  tmux send-keys -t "$SESSION:2" "nvim ." Enter

  # Window 3: review — branch diff vs base, ready to inspect
  tmux new-window -t "$SESSION" -n "review" -c "$WORKTREE_PATH"
  tmux send-keys -t "$SESSION:3" "git diff ${BASE}...HEAD --stat" Enter

  tmux select-window -t "$SESSION:1"
fi

# 4. Focus it (switch the current client if we're already in tmux, else attach)
if [[ -n "${TMUX:-}" ]]; then
  tmux switch-client -t "$SESSION"
else
  tmux attach -t "$SESSION"
fi
