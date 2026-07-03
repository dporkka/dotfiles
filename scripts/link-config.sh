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

# Detect mode: wsl | server (override with MODE=server)
if [[ -z "${MODE:-}" ]]; then
  if [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    MODE="wsl"
  else
    MODE="server"
  fi
fi

# XDG config directories (ghostty is a client-side terminal: skip on server)
LINK_DIRS="nvim tmux zellij"
[[ "$MODE" == "wsl" ]] && LINK_DIRS="$LINK_DIRS ghostty"
for d in $LINK_DIRS; do
  # Preserve Neovim's generated state file across the dir swap (regenerates anyway).
  if [[ "$d" == nvim && -f "$HOME/.config/nvim/lazyvim.json" && ! -L "$HOME/.config/nvim" ]]; then
    cp -f "$HOME/.config/nvim/lazyvim.json" "$DOTS/config/nvim/lazyvim.json" 2>/dev/null || true
  fi
  backup_then_link "$DOTS/config/$d" "$HOME/.config/$d"
done

# Single-file configs
backup_then_link "$DOTS/config/starship/starship.toml" "$HOME/.config/starship.toml"
backup_then_link "$DOTS/home/.zshrc" "$HOME/.zshrc"

# User systemd unit for the Zellij background service (AI agent persistence).
# Link only the specific unit rather than the whole systemd directory so other
# user units (e.g. from home-manager) are not shadowed.
mkdir -p "$HOME/.config/systemd/user"
backup_then_link "$DOTS/config/systemd/user/zellij.service" "$HOME/.config/systemd/user/zellij.service"

echo ""
echo "Done. (mode: $MODE) Live config now symlinks to $DOTS — one edit, everywhere."
echo "Note: live config follows the repo's checked-out branch. Secrets stay in"
echo "      ~/.config/zsh/secrets.zsh (untracked). Remove old *.bak.* once happy."
echo "      If this is the first install, run: zellij-service.sh enable && zellij-service.sh start"
