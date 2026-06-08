#!/usr/bin/env bash
# =============================================================================
# install.sh — one-shot bootstrap for a fresh machine
#
# SSH (recommended — needs your key on the server):
#   bash <(curl -sS https://raw.githubusercontent.com/dporkka/dotfiles/main/scripts/install.sh)
#
# HTTPS (no SSH key needed):
#   DOTFILES_REPO=https://github.com/dporkka/dotfiles.git \
#     bash <(curl -sS https://raw.githubusercontent.com/dporkka/dotfiles/main/scripts/install.sh)
#
# Already cloned:
#   bash ~/dotfiles/scripts/install.sh [--mode wsl|server]
# =============================================================================

set -euo pipefail

DOTFILES_REPO="${DOTFILES_REPO:-git@github.com:dporkka/dotfiles.git}"
DOTFILES_HTTPS="https://github.com/dporkka/dotfiles.git"
DOTFILES_DIR="${DOTFILES_DIR:-$HOME/dotfiles}"

# Parse --mode flag
MODE="${MODE:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*) MODE="${1#--mode=}"; shift ;;
    --mode)   MODE="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1"; shift ;;
  esac
done
export MODE

echo "==> Dotfiles installer"
echo "    Repo:   $DOTFILES_REPO"
echo "    Target: $DOTFILES_DIR"
[[ -n "$MODE" ]] && echo "    Mode:   $MODE"
echo ""

# ---------------------------------------------------------------------------
# 1. Ensure git is available
# ---------------------------------------------------------------------------

if ! command -v git &>/dev/null; then
  echo "==> Installing git..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y --no-install-recommends git
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y git
  else
    echo "ERROR: Cannot install git — unsupported package manager. Install git manually." >&2
    exit 1
  fi
fi

# ---------------------------------------------------------------------------
# 2. Clone dotfiles (or pull if already present)
# ---------------------------------------------------------------------------

if [[ -d "$DOTFILES_DIR/.git" ]]; then
  echo "==> Dotfiles already present at $DOTFILES_DIR — pulling latest..."
  git -C "$DOTFILES_DIR" pull --ff-only || true
else
  echo "==> Cloning dotfiles to $DOTFILES_DIR..."
  # Try SSH first; fall back to HTTPS if SSH keys are not set up
  git clone "$DOTFILES_REPO" "$DOTFILES_DIR" 2>/dev/null \
    || git clone "$DOTFILES_HTTPS" "$DOTFILES_DIR"
fi

# ---------------------------------------------------------------------------
# 3. Run bootstrap
# ---------------------------------------------------------------------------

echo "==> Running bootstrap..."
bash "$DOTFILES_DIR/scripts/bootstrap.sh"
