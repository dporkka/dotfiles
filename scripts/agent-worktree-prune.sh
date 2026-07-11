#!/usr/bin/env bash
# =============================================================================
# agent-worktree-prune.sh — remove merged agent worktrees older than N days.
#
# Usage: agent-worktree-prune.sh [--dry-run] [--max-age-days 14]
# =============================================================================
set -euo pipefail

DRY_RUN=false
MAX_AGE_DAYS=14

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)       DRY_RUN=true; shift ;;
    --max-age-days)  MAX_AGE_DAYS="$2"; shift 2 ;;
    *) shift ;;
  esac
done

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" \
  || { echo "not in a git repository" >&2; exit 1; }

NOW=$(date +%s)
PRUNED=0

while IFS= read -r wt_path; do
  [[ -d "$wt_path" ]] || continue

  # Skip the main worktree.
  [[ "$wt_path" == "$REPO_ROOT" ]] && continue

  # Check age: mtime of the worktree root.
  WT_MTIME=$(stat -c %Y "$wt_path" 2>/dev/null || echo 0)
  WT_AGE_DAYS=$(( (NOW - WT_MTIME) / 86400 ))
  if [[ $WT_AGE_DAYS -lt $MAX_AGE_DAYS ]]; then
    continue
  fi

  # Check if the branch is merged into origin/main.
  WT_BRANCH=$(git -C "$wt_path" branch --show-current 2>/dev/null) || continue
  [[ -n "$WT_BRANCH" ]] || continue

  # Fetch so we're comparing against current origin.
  git fetch origin main 2>/dev/null || true

  if git merge-base --is-ancestor "$WT_BRANCH" origin/main 2>/dev/null; then
    echo "pruning: $wt_path (branch $WT_BRANCH, age ${WT_AGE_DAYS}d, merged)"
    if ! $DRY_RUN; then
      git -C "$REPO_ROOT" worktree remove "$wt_path" --force 2>/dev/null || {
        echo "  WARNING: could not remove $wt_path" >&2
        continue
      }
      git -C "$REPO_ROOT" branch -D "$WT_BRANCH" 2>/dev/null || true
    fi
    PRUNED=$((PRUNED + 1))
  else
    echo "skipping: $wt_path (branch $WT_BRANCH, age ${WT_AGE_DAYS}d, NOT merged)"
  fi
done < <(git -C "$REPO_ROOT" worktree list --porcelain | awk '/^worktree/ {print $2}')

echo "pruned $PRUNED worktree(s)" "$($DRY_RUN && echo '(dry run)')"
