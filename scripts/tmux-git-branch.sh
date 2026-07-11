#!/bin/bash
# Cached git branch for tmux status-right — avoids forking git every 5s.
# Usage: tmux-git-branch.sh <directory>
CACHE_DIR="${XDG_CACHE_DIR:-$HOME/.cache}/tmux"
CACHE_TTL=30  # seconds before refreshing

dir="${1:-}"
[ -n "$dir" ] || exit 0

# Derive a stable cache key from the directory path.
cache_key=$(echo "$dir" | tr '/' '_')
CACHE_FILE="$CACHE_DIR/git-branch-$cache_key"

# Return cached value if fresh.
if [ -f "$CACHE_FILE" ]; then
  now=$(date +%s)
  cached_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)
  if [ $((now - cached_time)) -lt "$CACHE_TTL" ]; then
    cat "$CACHE_FILE"
    exit 0
  fi
fi

# Resolve git dir; bail if not a repo.
git_dir=$(cd "$dir" 2>/dev/null && git rev-parse --git-dir 2>/dev/null) || exit 0

# Get branch.
branch=$(cd "$dir" 2>/dev/null && git branch --show-current 2>/dev/null)
if [ -n "$branch" ]; then
  mkdir -p "$CACHE_DIR" 2>/dev/null
  echo "$branch" > "$CACHE_FILE"
  echo "$branch"
fi
