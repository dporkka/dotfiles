#!/usr/bin/env bash
# =============================================================================
# agent-checkpoint.sh — auto-commit before agent sessions, rollback on demand.
#
# Creates lightweight git snapshots so you can safely experiment with agents
# and roll back unwanted changes in one command.
#
# Usage:
#   agent-checkpoint.sh save      — git add + commit if anything changed
#   agent-checkpoint.sh rollback  — git reset --hard HEAD~1 (with confirm)
#   agent-checkpoint.sh status    — show last checkpoint and dirty files
# =============================================================================

set -euo pipefail

CMD="${1:-}"
CHECKPOINT_MSG_PREFIX="${AGENT_CHECKPOINT_PREFIX:-checkpoint: pre-agent}"

# Resolve the repo root from the script's own location (dotfiles repo).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null)" || {
  echo "[agent-checkpoint] not inside a git repository — nothing to do" >&2
  exit 0
}

cd "$REPO_ROOT"

save_checkpoint() {
  # Stage all changes (new, modified, deleted).
  git add -A 2>/dev/null || true

  # No-op if nothing changed.
  if git diff-index --quiet HEAD 2>/dev/null; then
    echo "[agent-checkpoint] working tree clean — no checkpoint needed"
    return 0
  fi

  local stamp
  stamp="$(date -Is 2>/dev/null || date -u +'%Y-%m-%dT%H:%M:%SZ')"

  if git commit -m "${CHECKPOINT_MSG_PREFIX} ${stamp}" >/dev/null 2>&1; then
    echo "[agent-checkpoint] checkpoint created at $(git rev-parse --short HEAD)"
  else
    echo "[agent-checkpoint] commit failed — maybe nothing changed" >&2
    return 0
  fi
}

rollback_checkpoint() {
  local last_msg
  last_msg="$(git log -1 --pretty=format:'%s' 2>/dev/null || true)"

  echo "WARNING: This will discard ALL uncommitted changes and undo the last commit."
  echo "  Last commit: ${last_msg:-<none>}"
  echo -n "Proceed? [y/N] "
  read -r confirm </dev/tty 2>/dev/null || read -r confirm
  case "$confirm" in
    y|Y|yes|YES)
      git reset --hard HEAD~1 2>/dev/null || {
        echo "[agent-checkpoint] nothing to roll back (no previous commit)" >&2
        return 0
      }
      echo "[agent-checkpoint] rolled back to $(git rev-parse --short HEAD)"
      ;;
    *)
      echo "[agent-checkpoint] rollback cancelled"
      ;;
  esac
}

show_status() {
  local last_commit last_msg
  last_commit="$(git rev-parse --short HEAD 2>/dev/null || echo '<none>')"
  last_msg="$(git log -1 --pretty=format:'%s' 2>/dev/null || echo '<no commits>')"

  echo "=== Checkpoint Status ==="
  echo "  HEAD:         ${last_commit}"
  echo "  Last message: ${last_msg}"
  echo ""

  local dirty
  dirty="$(git status --short 2>/dev/null || true)"
  if [[ -n "$dirty" ]]; then
    echo "  Uncommitted changes ($(echo "$dirty" | wc -l) file(s)):"
    echo "$dirty" | sed 's/^/    /'
  else
    echo "  Working tree is clean."
  fi
}

case "$CMD" in
  save)    save_checkpoint ;;
  rollback) rollback_checkpoint ;;
  status)  show_status ;;
  *)
    echo "Usage: agent-checkpoint.sh {save|rollback|status}" >&2
    exit 2
    ;;
esac
