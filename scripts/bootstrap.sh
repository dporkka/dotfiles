#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — complete environment setup from scratch
# Run: bash bootstrap.sh
# Safe to re-run: idempotent where possible
# =============================================================================

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="/tmp/bootstrap-$(date +%Y%m%d-%H%M%S).log"

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_FILE"; }
success() { echo "✓ $*" | tee -a "$LOG_FILE"; }
warn() { echo "⚠ $*" | tee -a "$LOG_FILE"; }
error() { echo "✗ $*" | tee -a "$LOG_FILE" >&2; }

# ---------------------------------------------------------------------------
# 1. SYSTEM PACKAGES
# ---------------------------------------------------------------------------

log "Installing system packages..."

sudo apt-get update -qq

sudo apt-get install -y --no-install-recommends \
  build-essential \
  curl \
  wget \
  git \
  git-delta \
  unzip \
  zip \
  jq \
  yq \
  fd-find \
  ripgrep \
  fzf \
  bat \
  tmux \
  zsh \
  stow \
  wslu \
  libsecret-tools \
  libsecret-1-dev \
  sqlite3 \
  ca-certificates \
  gnupg \
  lsb-release \
  software-properties-common \
  python3 \
  python3-pip \
  python3-venv \
  direnv \
  tree \
  htop

success "System packages installed"

# ---------------------------------------------------------------------------
# 2. NEOVIM — install latest stable from GitHub
# ---------------------------------------------------------------------------

log "Installing Neovim..."

NVIM_VERSION="stable"
NVIM_URL="https://github.com/neovim/neovim/releases/${NVIM_VERSION}/download/nvim-linux-x86_64.tar.gz"

if ! nvim --version &>/dev/null || [[ "$(nvim --version | head -1)" < "NVIM v0.10" ]]; then
  curl -sL "$NVIM_URL" -o /tmp/nvim.tar.gz
  sudo tar -C /opt -xzf /tmp/nvim.tar.gz
  sudo ln -sf /opt/nvim-linux-x86_64/bin/nvim /usr/local/bin/nvim
  rm /tmp/nvim.tar.gz
  success "Neovim installed: $(nvim --version | head -1)"
else
  success "Neovim already installed: $(nvim --version | head -1)"
fi

# ---------------------------------------------------------------------------
# 3. STARSHIP PROMPT
# ---------------------------------------------------------------------------

log "Installing starship..."
if ! command -v starship &>/dev/null; then
  curl -sS https://starship.rs/install.sh | sh -s -- --yes
  success "Starship installed"
else
  success "Starship already installed"
fi

# ---------------------------------------------------------------------------
# 4. ZOXIDE — smarter cd
# ---------------------------------------------------------------------------

log "Installing zoxide..."
if ! command -v zoxide &>/dev/null; then
  curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
  success "Zoxide installed"
else
  success "Zoxide already installed"
fi

# ---------------------------------------------------------------------------
# 5. EZA — modern ls
# ---------------------------------------------------------------------------

log "Installing eza..."
if ! command -v eza &>/dev/null; then
  sudo mkdir -p /etc/apt/keyrings
  wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
    | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
  echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
    | sudo tee /etc/apt/sources.list.d/gierens.list
  sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
  sudo apt-get update -qq && sudo apt-get install -y eza
  success "Eza installed"
else
  success "Eza already installed"
fi

# ---------------------------------------------------------------------------
# 6. NODE.JS via pnpm (faster than nvm for most workflows)
# ---------------------------------------------------------------------------

log "Installing pnpm + Node.js..."
if ! command -v pnpm &>/dev/null; then
  curl -fsSL https://get.pnpm.io/install.sh | sh -
  export PNPM_HOME="$HOME/.local/share/pnpm"
  export PATH="$PNPM_HOME:$PATH"
  pnpm env use --global lts
  success "pnpm + Node.js LTS installed"
else
  success "pnpm already installed: $(pnpm --version)"
fi

# Install NVM as fallback (some tools require it)
if [[ ! -d "$HOME/.nvm" ]]; then
  log "Installing nvm as fallback..."
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
fi

# ---------------------------------------------------------------------------
# 7. UV — Python package manager (fast)
# ---------------------------------------------------------------------------

log "Installing uv..."
if ! command -v uv &>/dev/null; then
  curl -LsSf https://astral.sh/uv/install.sh | sh
  success "uv installed"
else
  success "uv already installed"
fi

# ---------------------------------------------------------------------------
# 8. LAZYGIT
# ---------------------------------------------------------------------------

log "Installing lazygit..."
if ! command -v lazygit &>/dev/null; then
  LAZYGIT_VERSION=$(curl -s "https://api.github.com/repos/jesseduffield/lazygit/releases/latest" | jq -r '.tag_name')
  curl -Lo /tmp/lazygit.tar.gz \
    "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION#v}_Linux_x86_64.tar.gz"
  sudo tar -C /usr/local/bin -xzf /tmp/lazygit.tar.gz lazygit
  rm /tmp/lazygit.tar.gz
  success "Lazygit installed"
else
  success "Lazygit already installed"
fi

# ---------------------------------------------------------------------------
# 9. DELTA — better git diff
# ---------------------------------------------------------------------------

log "Installing git-delta..."
if ! command -v delta &>/dev/null; then
  DELTA_VERSION=$(curl -s "https://api.github.com/repos/dandavison/delta/releases/latest" | jq -r '.tag_name')
  curl -Lo /tmp/delta.deb \
    "https://github.com/dandavison/delta/releases/latest/download/git-delta_${DELTA_VERSION}_amd64.deb"
  sudo dpkg -i /tmp/delta.deb
  rm /tmp/delta.deb
  success "Delta installed"
else
  success "Delta already installed"
fi

# ---------------------------------------------------------------------------
# 10. WIN32YANK — WSL2 clipboard bridge for Neovim
# ---------------------------------------------------------------------------

log "Installing win32yank for WSL2 clipboard..."
if ! command -v win32yank.exe &>/dev/null; then
  curl -sLo /tmp/win32yank.zip \
    "https://github.com/equalsraf/win32yank/releases/latest/download/win32yank-x64.zip"
  mkdir -p ~/.local/bin
  unzip -oq /tmp/win32yank.zip win32yank.exe -d ~/.local/bin/
  chmod +x ~/.local/bin/win32yank.exe
  rm /tmp/win32yank.zip
  success "win32yank installed"
else
  success "win32yank already installed"
fi

# ---------------------------------------------------------------------------
# 11. GITHUB CLI
# ---------------------------------------------------------------------------

log "Installing GitHub CLI..."
if ! command -v gh &>/dev/null; then
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
    | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
  sudo apt-get update -qq && sudo apt-get install -y gh
  success "GitHub CLI installed"
else
  success "GitHub CLI already installed"
fi

# ---------------------------------------------------------------------------
# 12. DOCKER CLI (if Docker Desktop not available)
# ---------------------------------------------------------------------------

if ! command -v docker &>/dev/null; then
  log "Docker not found. Install Docker Desktop for Windows with WSL2 integration."
  log "https://docs.docker.com/desktop/wsl/"
else
  success "Docker available: $(docker --version)"
fi

# ---------------------------------------------------------------------------
# 13. TPM — tmux plugin manager
# ---------------------------------------------------------------------------

log "Installing tmux plugin manager (TPM)..."
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  success "TPM installed"
else
  success "TPM already installed"
fi

# ---------------------------------------------------------------------------
# 14. LOCALE — generate en_US.UTF-8 (prevents Ghostty/GTK locale warnings)
# ---------------------------------------------------------------------------

log "Configuring locale..."
if ! locale -a 2>/dev/null | grep -q "en_US.utf8"; then
  sudo locale-gen en_US.UTF-8
  sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
  success "Locale en_US.UTF-8 generated"
else
  success "Locale already configured"
fi

# ---------------------------------------------------------------------------
# 14b. INOTIFY LIMITS — critical for Next.js / Vite file watching
# ---------------------------------------------------------------------------

log "Configuring inotify limits..."
INOTIFY_CONF="/etc/sysctl.d/99-wsl-inotify.conf"
if [[ ! -f "$INOTIFY_CONF" ]] || ! grep -q "524288" "$INOTIFY_CONF" 2>/dev/null; then
  cat <<'EOF' | sudo tee "$INOTIFY_CONF"
# WSL2 inotify optimization for Next.js/Vite/TypeScript file watchers
# Default (8192) is too low for large monorepos with hot reload
fs.inotify.max_user_watches=524288
fs.inotify.max_user_instances=512
fs.inotify.max_queued_events=32768
EOF
  sudo sysctl -p "$INOTIFY_CONF" &>/dev/null || true
  success "inotify limits configured"
else
  success "inotify limits already configured"
fi

# ---------------------------------------------------------------------------
# 15. INSTALL DOTFILES via stow
# ---------------------------------------------------------------------------

log "Linking dotfiles..."

# Create XDG directories
mkdir -p ~/.config ~/.local/bin ~/.local/share ~/.cache

# Link configs
cd "$DOTFILES_DIR"

# Link individual config directories
for dir in nvim tmux starship git ghostty; do
  if [[ -d "config/$dir" ]]; then
    mkdir -p "$HOME/.config/$dir"
    # Use rsync for merging (safer than stow for existing configs)
    rsync -av "config/$dir/" "$HOME/.config/$dir/" --ignore-existing
    success "Linked config/$dir"
  fi
done

# Link home files (with backup)
for file in home/.*; do
  [[ -f "$file" ]] || continue
  basename=$(basename "$file")
  if [[ -f "$HOME/$basename" && ! -L "$HOME/$basename" ]]; then
    cp "$HOME/$basename" "$HOME/${basename}.backup.$(date +%Y%m%d)"
    warn "Backed up existing $basename"
  fi
  cp -n "$file" "$HOME/$basename" 2>/dev/null || warn "$basename already exists, skipping"
done

# Starship config
mkdir -p ~/.config
cp -n config/starship/starship.toml ~/.config/starship.toml 2>/dev/null || true

success "Dotfiles linked"

# ---------------------------------------------------------------------------
# 16. CHANGE DEFAULT SHELL TO ZSH
# ---------------------------------------------------------------------------

if [[ "$SHELL" != "$(which zsh)" ]]; then
  log "Setting zsh as default shell..."
  chsh -s "$(which zsh)"
  success "Shell changed to zsh (restart shell to take effect)"
fi

# ---------------------------------------------------------------------------
# 17. INSTALL CLAUDE CODE CLI
# ---------------------------------------------------------------------------

log "Installing Claude Code CLI..."
if ! command -v claude &>/dev/null; then
  if command -v npm &>/dev/null || command -v pnpm &>/dev/null; then
    npm install -g @anthropic-ai/claude-code 2>/dev/null \
      || pnpm add -g @anthropic-ai/claude-code 2>/dev/null \
      || warn "Could not install Claude Code — install Node.js first, then run: npm install -g @anthropic-ai/claude-code"
  else
    warn "Node.js not available yet. After shell restart, run: npm install -g @anthropic-ai/claude-code"
  fi
else
  success "Claude Code already installed"
fi

# ---------------------------------------------------------------------------
# DONE
# ---------------------------------------------------------------------------

echo ""
echo "=============================================="
echo "Bootstrap complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "1. Copy wsl/.wslconfig to C:\\Users\\<YourUser>\\.wslconfig"
echo "2. Copy wsl/wsl.conf to /etc/wsl.conf (already done if you ran as root)"
echo "3. Restart WSL: wsl --shutdown (from PowerShell)"
echo "4. Open a new terminal — zsh will be your shell"
echo "5. Start nvim — LazyVim will install plugins automatically"
echo "6. In tmux, press prefix+I to install tmux plugins"
echo "7. Run: gh auth login"
echo ""
echo "Log saved to: $LOG_FILE"
