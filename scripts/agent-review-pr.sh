#!/usr/bin/env bash
# =============================================================================
# agent-review-pr.sh — checkout a PR, dump its diff as context, launch an agent.
#
# Usage:
#   agent-review-pr.sh <pr-number> [--agent cmd] [--base branch]
#
# Examples:
#   agent-review-pr.sh 42
#   agent-review-pr.sh 137 --agent kimi --base develop
# =============================================================================
set -euo pipefail

PR="${1:-}"
[[ -n "$PR" ]] || { echo "Usage: agent-review-pr.sh <pr-number> [--agent cmd] [--base branch]" >&2; exit 2; }
shift

AGENT="claude"
BASE="main"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --agent) AGENT="$2"; shift 2 ;;
    --base)  BASE="$2";  shift 2 ;;
    *) shift ;;
  esac
done

command -v gh >/dev/null 2>&1 || { echo "gh CLI required: https://cli.github.com" >&2; exit 1; }
command -v "$AGENT" >/dev/null 2>&1 || { echo "agent '$AGENT' not found on PATH" >&2; exit 1; }

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || { echo "not in a git repository" >&2; exit 1; }

# Fetch PR metadata.
PR_TITLE=$(gh pr view "$PR" --json title -q '.title' 2>/dev/null) || true
PR_BRANCH=$(gh pr view "$PR" --json headRefName -q '.headRefName' 2>/dev/null) || true
CONTEXT_FILE="/tmp/pr-${PR}-context.md"

echo "PR #${PR}: ${PR_TITLE:-unknown}"
echo "Branch: ${PR_BRANCH:-unknown}"

# Checkout the PR branch.
gh pr checkout "$PR" --force 2>/dev/null || {
  echo "Could not checkout PR #$PR; fetching and trying again..." >&2
  gh pr checkout "$PR" --force
}

# Dump PR body + diff as agent context.
{
  echo "# PR #${PR}: ${PR_TITLE:-No title}"
  echo
  echo "## Description"
  gh pr view "$PR" --json body -q '.body' 2>/dev/null || echo "(no description)"
  echo
  echo "## Diff"
  echo '```diff'
  gh pr diff "$PR" 2>/dev/null || echo "(diff unavailable)"
  echo '```'
} > "$CONTEXT_FILE"

# Determine a session name from the PR branch.
REPO_NAME="$(basename "$REPO_ROOT")"
SLUG="${PR_BRANCH:-pr-$PR}"
SLUG="${SLUG//\//-}"
SESSION="review-${REPO_NAME}-${SLUG}"

# Launch agent in a tmux session, pre-loading the context.
if [[ -n "${TMUX:-}" ]]; then
  tmux new-session -d -s "$SESSION" -c "$REPO_ROOT" 2>/dev/null || true
  tmux send-keys -t "$SESSION" "cat $CONTEXT_FILE" Enter
  tmux send-keys -t "$SESSION" "$AGENT" Enter
  tmux switch-client -t "$SESSION"
else
  tmux new-session -A -s "$SESSION" -c "$REPO_ROOT"
  tmux send-keys -t "$SESSION" "cat $CONTEXT_FILE" Enter
  tmux send-keys -t "$SESSION" "$AGENT" Enter
fi

echo "Context saved to $CONTEXT_FILE"
echo "Agent '$AGENT' launched in session '$SESSION'"
