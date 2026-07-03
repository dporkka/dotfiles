#!/usr/bin/env bash
# =============================================================================
# zellij-agent-worktree.sh — spin up an isolated AI agent in its own git worktree.
#
# One command: git worktree -> deps -> Zellij session -> launch the agent.
# Each agent gets its own branch + working directory, so parallel agents never
# collide. The session is tagged by name so it appears in the agent dashboard
# (Alt+a / zellij-agent-dashboard.sh), registered in agent-registry.sh, and
# Claude Code hooks (agent-hook.sh) light up its tab state.
#
# Usage:
#   zellij-agent-worktree.sh <branch> [initial prompt words...]
#     --base  <branch>   base to branch from   (default: main)
#     --agent <cmd>      agent command to run   (default: claude)
#
# Examples:
#   zellij-agent-worktree.sh feat/payments
#   zellij-agent-worktree.sh fix/login --base develop add MFA to the login form
#   zellij-agent-worktree.sh chore/types --agent aider
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
  || { echo "Usage: zellij-agent-worktree.sh <branch> [prompt...] [--base b] [--agent cmd]" >&2; exit 2; }
PROMPT="${PROMPT_WORDS[*]:-}"

command -v zellij >/dev/null 2>&1 || { echo "zellij required" >&2; exit 1; }
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
LAYOUT_DIR="${DOTS:-$HOME/dotfiles}/config/zellij/layouts"
LAYOUT="${LAYOUT_DIR}/agent.kdl"

# Human-readable command for the registry; escaped version for the Zellij layout.
AGENT_CMD_DISPLAY="$AGENT"
[[ -n "$PROMPT" ]] && AGENT_CMD_DISPLAY="$AGENT_CMD_DISPLAY $PROMPT"
AGENT_CMD_ESCAPED="$AGENT"
[[ -n "$PROMPT" ]] && AGENT_CMD_ESCAPED="$AGENT_CMD_ESCAPED $(printf '%q' "$PROMPT")"

export ZELLIJ_AGENT_CMD="$AGENT_CMD_ESCAPED"
if ! zellij list-sessions --no-formatting 2>/dev/null | awk '{print $1}' | grep -qxF "$SESSION"; then
  # Register before launching so hooks that fire immediately can update state.
  "$HOME/dotfiles/scripts/agent-registry.sh" register "$SESSION" zellij \
    worktree="$WORKTREE_PATH" \
    branch="$BRANCH" \
    base="$BASE" \
    agent_cmd="$AGENT_CMD_DISPLAY" \
    agent="$AGENT" \
    prompt="$PROMPT" \
    pid="$$" 2>/dev/null || true

  (cd "$WORKTREE_PATH" && zellij --layout "$LAYOUT" attach -b "$SESSION")
fi

echo ""
echo "Session created: $SESSION"
echo "Worktree: $WORKTREE_PATH"
echo "Commands:"
echo "  Attach:  zellij attach $SESSION"
echo "  List:    zellij list-sessions"
echo "  Kill:    zellij kill-session $SESSION"
echo ""

# 4. Focus it (switch the current client if we're already in zellij, else attach)
if [[ -t 0 ]]; then
  if [[ -n "${ZELLIJ:-}" ]]; then
    zellij action switch-session "$SESSION"
  else
    zellij attach "$SESSION"
  fi
else
  echo "Not running in a terminal; start zellij interactively to attach to $SESSION"
fi
