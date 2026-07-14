#!/usr/bin/env bash
# =============================================================================
# agent-worktree-prune-all.sh — prune merged agent worktrees across all repos.
#
# For each git repo found directly under ${AGENT_REPO_ROOTS:-"$HOME/Dev"},
# runs agent-worktree-prune.sh --max-age-days 14 (merged fanout worktrees only)
# with cwd set to that repo. Skips non-git dirs; one failing repo never aborts
# the whole run.
#
# Usage: agent-worktree-prune-all.sh [--dry-run]
# =============================================================================

set -euo pipefail

DOTS="${DOTS:-$HOME/dotfiles}"
REPO_ROOTS="${AGENT_REPO_ROOTS:-$HOME/Dev}"
MAX_AGE_DAYS=14

EXTRA_ARGS=()
[[ "${1:-}" == "--dry-run" ]] && EXTRA_ARGS+=(--dry-run)

repos_checked=0
repos_failed=0

if [[ ! -d "$REPO_ROOTS" ]]; then
  echo "agent-worktree-prune-all: repo root not found: $REPO_ROOTS" >&2
  exit 0
fi

for d in "$REPO_ROOTS"/*/; do
  repo="${d%/}"
  # Skip non-git dirs (plain dir or worktree checkout both have .git).
  if ! git -C "$repo" rev-parse --git-dir >/dev/null 2>&1; then
    continue
  fi
  repos_checked=$((repos_checked + 1))
  echo "== $repo =="
  if ! (cd "$repo" && "$DOTS/scripts/agent-worktree-prune.sh" --max-age-days "$MAX_AGE_DAYS" "${EXTRA_ARGS[@]}"); then
    echo "WARNING: prune failed in $repo; continuing" >&2
    repos_failed=$((repos_failed + 1))
  fi
done

echo "agent-worktree-prune-all: checked $repos_checked repo(s), $repos_failed failed${EXTRA_ARGS[*]:+ (dry run)}"
