#!/usr/bin/env bash
# =============================================================================
# link-config.sh — symlink live config into this repo (single source of truth).
#
# Fixes the drift trap: previously bootstrap COPIED config -> ~/.config with
# rsync --ignore-existing / cp -n, so edits never propagated either way and the
# two trees silently diverged. After this, editing the repo IS editing live.
#
# Backs up any existing real (non-symlink) target to <name>.bak.<timestamp>.
# Idempotent: re-running just refreshes the links.
#
# Usage:
#   bash link-config.sh [--shell bash|zsh]
# =============================================================================

set -euo pipefail

DOTS="${DOTS:-$HOME/dotfiles}"
ts="$(date +%Y%m%d-%H%M%S)"

backup_then_link() {  # $1 = source (repo), $2 = dest (live)
  local src="$1" dst="$2"
  [[ -e "$src" ]] || { echo "skip: no source $src"; return; }
  mkdir -p "$(dirname "$dst")"
  if [[ -L "$dst" ]]; then
    rm "$dst"
  elif [[ -e "$dst" ]]; then
    mv "$dst" "${dst}.bak.${ts}"
    echo "backed up $dst -> ${dst}.bak.${ts}"
  fi
  ln -s "$src" "$dst"
  echo "linked $dst -> $src"
}

# ------------------------------------------------------------------------------
# Argument parsing
# ------------------------------------------------------------------------------
MODE="${MODE:-}"
SHELL_CHOICE="${SHELL_CHOICE:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode=*) MODE="${1#--mode=}"; shift ;;
    --mode)   MODE="${2:-}"; shift 2 ;;
    --shell=*) SHELL_CHOICE="${1#--shell=}"; shift ;;
    --shell)   SHELL_CHOICE="${2:-}"; shift 2 ;;
    *) echo "Unknown arg: $1"; shift ;;
  esac
done

# ------------------------------------------------------------------------------
# Detect mode: wsl | server (override with MODE=server)
# ------------------------------------------------------------------------------
if [[ -z "${MODE:-}" ]]; then
  if [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    MODE="wsl"
  else
    MODE="server"
  fi
fi

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
    echo "No --shell provided and stdin is not a TTY; defaulting to zsh."
    SHELL_CHOICE="zsh"
  fi
fi

case "$SHELL_CHOICE" in
  bash|zsh) ;;
  *) echo "ERROR: unsupported shell '$SHELL_CHOICE'. Use bash or zsh." >&2; exit 1 ;;
esac

echo ""
echo "link-config.sh: mode=$MODE, shell=$SHELL_CHOICE"
echo ""

# ------------------------------------------------------------------------------
# XDG config directories
# ghostty is a client-side terminal: skip on server
# ------------------------------------------------------------------------------
LINK_DIRS="nvim tmux zellij"
[[ "$MODE" == "wsl" ]] && LINK_DIRS="$LINK_DIRS ghostty"
for d in $LINK_DIRS; do
  # Preserve Neovim's generated state file across the dir swap (regenerates anyway).
  if [[ "$d" == nvim && -f "$HOME/.config/nvim/lazyvim.json" && ! -L "$HOME/.config/nvim" ]]; then
    cp -f "$HOME/.config/nvim/lazyvim.json" "$DOTS/config/nvim/lazyvim.json" 2>/dev/null || true
  fi
  backup_then_link "$DOTS/config/$d" "$HOME/.config/$d"
done

# ------------------------------------------------------------------------------
# Single-file configs
# ------------------------------------------------------------------------------
backup_then_link "$DOTS/config/starship/starship.toml" "$HOME/.config/starship.toml"

# ------------------------------------------------------------------------------
# Shell config (bash or zsh)
# ------------------------------------------------------------------------------
if [[ "$SHELL_CHOICE" == "bash" ]]; then
  backup_then_link "$DOTS/home/.bashrc" "$HOME/.bashrc"
  backup_then_link "$DOTS/home/.bash_profile" "$HOME/.bash_profile"
  backup_then_link "$DOTS/home/.bashrc.d" "$HOME/.bashrc.d"
  # If zsh was previously linked, leave it pointing at the repo (harmless) but
  # warn that bash is now the active choice.
  if [[ -L "$HOME/.zshrc" ]]; then
    echo "note: ~/.zshrc is still symlinked to the repo, but bash is now the chosen shell."
  fi
else
  backup_then_link "$DOTS/home/.zshrc" "$HOME/.zshrc"
  if [[ -L "$HOME/.bashrc" ]]; then
    echo "note: ~/.bashrc is still symlinked to the repo, but zsh is now the chosen shell."
  fi
fi

# ------------------------------------------------------------------------------
# Other home files (git config, ignore rules)
# ------------------------------------------------------------------------------
for file in "$DOTS"/home/.gitconfig "$DOTS"/home/.gitignore_global; do
  [[ -f "$file" ]] || continue
  backup_then_link "$file" "$HOME/$(basename "$file")"
done

# ------------------------------------------------------------------------------
# User systemd units for tmux + Zellij background services (AI agent persistence).
# Link only the specific units rather than the whole systemd directory so other
# user units (e.g. from home-manager) are not shadowed.
# ------------------------------------------------------------------------------
mkdir -p "$HOME/.config/systemd/user"
for unit in zellij.service tmux.service tmux-snapshot.service tmux-snapshot.timer backup-home-gdrive.service backup-home-gdrive.timer; do
  backup_then_link "$DOTS/config/systemd/user/$unit" "$HOME/.config/systemd/user/$unit"
done

# Best-effort reload + enable so services survive logout/reboot.
if command -v systemctl >/dev/null 2>&1; then
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  systemctl --user enable zellij.service tmux.service tmux-snapshot.timer >/dev/null 2>&1 || true
fi

echo ""
echo "Done. (mode: $MODE, shell: $SHELL_CHOICE) Live config now symlinks to $DOTS — one edit, everywhere."
echo "Note: live config follows the repo's checked-out branch. Secrets stay in"
echo "      ~/.config/zsh/secrets.zsh (untracked). Remove old *.bak.* once happy."
echo "      Start services with: systemctl --user start tmux.service zellij.service"
echo "      Backup timer:        systemctl --user start backup-home-gdrive.timer"
