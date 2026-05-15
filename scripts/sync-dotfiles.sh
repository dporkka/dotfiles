#!/usr/bin/env bash
# =============================================================================
# sync-dotfiles.sh — commit and push dotfiles changes
# Run after making config changes you want to persist
# =============================================================================

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$DOTFILES_DIR"

# Pull latest first
git pull --rebase --autostash

# Stage all changes
git add -A

# Show what's changing
if git diff --cached --quiet; then
  echo "No changes to commit"
  exit 0
fi

echo "Changes to commit:"
git diff --cached --stat

# Commit
MSG="${1:-chore: update dotfiles $(date +%Y-%m-%d)}"
git commit -m "$MSG"

# Push
git push

echo "Dotfiles synced"
