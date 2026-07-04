#!/usr/bin/env bash
# =============================================================================
# setup-workstation.sh — one-shot developer environment bundle.
#
# This script is the single entrypoint for applying all of my computer
# optimizations to a fresh local machine, laptop, or VPS. It clones/updates the
# relevant repos and runs each installer in the right order.
#
# Usage:
#   bash <(curl -sS https://raw.githubusercontent.com/dporkka/dotfiles/main/scripts/setup-workstation.sh)
#
# Or, after cloning:
#   bash ~/dotfiles/scripts/setup-workstation.sh [options]
#
# Options:
#   --mode desktop|server    desktop = local GUI/WSL; server = headless VPS
#   --shell bash|zsh         default login shell
#   --with-runtimes          also run dev-setup (Node/Go/Python/Rust + LSPs)
#   --help                   show this help
#
# The script auto-detects mode when not provided:
#   - WSL -> desktop
#   - GNOME desktop session -> desktop
#   - otherwise -> server
# =============================================================================

set -euo pipefail

# ------------------------------------------------------------------------------
# Configuration
# ------------------------------------------------------------------------------
REPO_DOTFILES="https://github.com/dporkka/dotfiles.git"
REPO_WEZTERM="https://github.com/dporkka/command-tower-wezterm.git"
REPO_KEYBOARD="https://github.com/dporkka/linux-keyboard-setup.git"
REPO_DEVSETUP="https://github.com/dporkka/dev-setup.git"

MODE=""
SHELL_CHOICE=""
WITH_RUNTIMES=false

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------
log()  { echo "==> $*"; }
warn() { echo "⚠ $*" >&2; }
fail() { echo "✗ $*" >&2; exit 1; }

usage() {
  sed -n '/^# Usage:/,/^# The script auto-detects/p' "$0" | sed 's/^# //'
}

clone_or_pull() {
  local url="$1" dir="$2"
  if [[ -d "$dir/.git" ]]; then
    log "Pulling $dir ..."
    git -C "$dir" pull --ff-only || warn "Could not pull $dir"
  else
    log "Cloning $url -> $dir ..."
    git clone "$url" "$dir"
  fi
}

backup_then_link() {
  local src="$1" dst="$2"
  local ts
  ts="$(date +%Y%m%d-%H%M%S)"
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    mv "$dst" "${dst}.bak.${ts}"
    warn "Backed up $dst -> ${dst}.bak.${ts}"
  fi
  ln -sfn "$src" "$dst"
  log "Linked $dst -> $src"
}

# ------------------------------------------------------------------------------
# Argument parsing
# ------------------------------------------------------------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*) MODE="${1#--mode=}"; shift ;;
    --mode)   MODE="${2:-}"; shift 2 ;;
    --shell=*) SHELL_CHOICE="${1#--shell=}"; shift ;;
    --shell)   SHELL_CHOICE="${2:-}"; shift 2 ;;
    --with-runtimes) WITH_RUNTIMES=true; shift ;;
    --help|-h) usage; exit 0 ;;
    *) fail "Unknown argument: $1" ;;
  esac
done

# ------------------------------------------------------------------------------
# Mode auto-detection
# ------------------------------------------------------------------------------
if [[ -z "$MODE" ]]; then
  if [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    MODE="desktop"
  elif [[ -n "${DESKTOP_SESSION:-}" ]] || pgrep -x gnome-shell &>/dev/null || pgrep -x sway &>/dev/null; then
    MODE="desktop"
  else
    MODE="server"
  fi
fi
case "$MODE" in
  desktop|server) ;;
  *) fail "Invalid mode '$MODE'. Use desktop or server." ;;
esac
log "Mode: $MODE"

# ------------------------------------------------------------------------------
# Shell selection
# ------------------------------------------------------------------------------
if [[ -z "$SHELL_CHOICE" ]]; then
  if [[ -t 0 ]]; then
    echo ""
    echo "Which shell should be the default/login shell?"
    PS3="Select shell: "
    select opt in bash zsh; do
      case "$opt" in
        bash|zsh) SHELL_CHOICE="$opt"; break ;;
        *) echo "Invalid choice. Please enter 1 (bash) or 2 (zsh)." ;;
      esac
    done
  else
    log "No --shell provided and stdin is not a TTY; defaulting to bash."
    SHELL_CHOICE="bash"
  fi
fi
case "$SHELL_CHOICE" in
  bash|zsh) ;;
  *) fail "Invalid shell '$SHELL_CHOICE'. Use bash or zsh." ;;
esac
log "Shell: $SHELL_CHOICE"

# ------------------------------------------------------------------------------
# Pre-flight checks
# ------------------------------------------------------------------------------
command -v git &>/dev/null || fail "git is required"
command -v curl &>/dev/null || fail "curl is required"
sudo -n true 2>/dev/null || warn "sudo access may be required for package installs"

# dev-setup is zsh-oriented; avoid polluting versioned bash configs.
if [[ "$WITH_RUNTIMES" == true && "$SHELL_CHOICE" != "zsh" ]]; then
  fail "--with-runtimes currently requires --shell zsh (dev-setup appends to .zshrc)"
fi

# ------------------------------------------------------------------------------
# 1. Clone / update repos
# ------------------------------------------------------------------------------
log "Cloning / updating repositories..."
clone_or_pull "$REPO_DOTFILES" "$HOME/dotfiles"
clone_or_pull "$REPO_WEZTERM" "$HOME/wezterm-config"
clone_or_pull "$REPO_KEYBOARD" "$HOME/linux-keyboard-setup"
if [[ "$WITH_RUNTIMES" == true ]]; then
  clone_or_pull "$REPO_DEVSETUP" "$HOME/dev-setup"
fi

# ------------------------------------------------------------------------------
# 2. Run dotfiles bootstrap
# ------------------------------------------------------------------------------
log "Running dotfiles bootstrap..."
export MODE
export SHELL_CHOICE
bash "$HOME/dotfiles/scripts/bootstrap.sh"

# ------------------------------------------------------------------------------
# 3. Link WezTerm config
# ------------------------------------------------------------------------------
log "Linking WezTerm config..."
backup_then_link "$HOME/wezterm-config" "$HOME/.config/wezterm"

# ------------------------------------------------------------------------------
# 4. Mode-specific extras
# ------------------------------------------------------------------------------
if [[ "$MODE" == "desktop" ]]; then
  log "Applying Linux keyboard setup..."
  bash "$HOME/linux-keyboard-setup/apply.sh" || warn "linux-keyboard-setup failed"
fi

if [[ "$MODE" == "server" ]]; then
  log "Setting up EternalTerminal server..."
  bash "$HOME/dotfiles/scripts/setup-et-server.sh" || warn "ET server setup failed"
fi

# ------------------------------------------------------------------------------
# 5. Optional language runtimes
# ------------------------------------------------------------------------------
if [[ "$WITH_RUNTIMES" == true ]]; then
  log "Running dev-setup (language runtimes + LSPs)..."
  bash "$HOME/dev-setup/bootstrap-vps.sh" || warn "dev-setup failed"
fi

# ------------------------------------------------------------------------------
# Done
# ------------------------------------------------------------------------------
echo ""
echo "=============================================================="
echo "Workstation setup complete!"
echo "=============================================================="
echo ""
echo "Mode:    $MODE"
echo "Shell:   $SHELL_CHOICE"
echo "Repos:   ~/dotfiles, ~/wezterm-config, ~/linux-keyboard-setup"
[[ "$WITH_RUNTIMES" == true ]] && echo "         ~/dev-setup"
echo ""
echo "Next steps:"
echo "  1. Restart your terminal / log out and back in."
echo "  2. Inside tmux, install plugins: prefix + I  (default prefix is C-a)"
echo "  3. Run 'gh auth login' if you use GitHub CLI."
echo "  4. Add secrets to ~/.config/zsh/secrets.zsh"
echo ""
echo "Connect to a remote server with:"
echo "  et user@host -c 'tmux new-session -A -s main'"
echo "Or use WezTerm: LEADER + e  /  LEADER + E"
