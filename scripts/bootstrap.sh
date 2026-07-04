#!/usr/bin/env bash
# =============================================================================
# bootstrap.sh — complete environment setup from scratch
# Run: bash bootstrap.sh
# Safe to re-run: idempotent where possible
# Override mode: MODE=server bash bootstrap.sh
# Override shell: SHELL_CHOICE=bash bash bootstrap.sh
# =============================================================================

set -euo pipefail

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOG_FILE="/tmp/bootstrap-$(date +%Y%m%d-%H%M%S).log"

# ---------------------------------------------------------------------------
# ARGUMENT / ENV PARSING
# ---------------------------------------------------------------------------
SHELL_CHOICE="${SHELL_CHOICE:-}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --shell=*) SHELL_CHOICE="${1#--shell=}"; shift ;;
    --shell)   SHELL_CHOICE="${2:-}"; shift 2 ;;
    *) echo "Unknown bootstrap arg: $1" >&2; shift ;;
  esac
done

log() { echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG_FILE"; }
success() { echo "✓ $*" | tee -a "$LOG_FILE"; }
warn() { echo "⚠ $*" | tee -a "$LOG_FILE"; }
error() { echo "✗ $*" | tee -a "$LOG_FILE" >&2; }

# ---------------------------------------------------------------------------
# ENVIRONMENT DETECTION — arch, mode, distro
# ---------------------------------------------------------------------------

# Architecture
ARCH=$(uname -m)
case "$ARCH" in
  x86_64)  NVIM_ARCH="x86_64"; DEB_ARCH="amd64"; LG_ARCH="x86_64" ;;
  aarch64) NVIM_ARCH="arm64";  DEB_ARCH="arm64"; LG_ARCH="arm64"   ;;
  *) warn "Unsupported arch: $ARCH — defaulting to x86_64 names; downloads may fail"
     NVIM_ARCH="x86_64"; DEB_ARCH="amd64"; LG_ARCH="x86_64" ;;
esac

# Mode: wsl | server (auto-detected; override with MODE=server bash bootstrap.sh)
if [[ -z "${MODE:-}" ]]; then
  if [[ -f /proc/version ]] && grep -qi microsoft /proc/version 2>/dev/null; then
    MODE="wsl"
  else
    MODE="server"
  fi
fi

# Shell choice: bash | zsh (default interactive prompt, or --shell / $SHELL_CHOICE)
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
    SHELL_CHOICE="zsh"
  fi
fi
case "$SHELL_CHOICE" in
  bash|zsh) log "Shell choice: $SHELL_CHOICE" ;;
  *) error "Unsupported shell '$SHELL_CHOICE'. Use bash or zsh."; exit 1 ;;
esac

# Package manager
if command -v apt-get &>/dev/null; then
  DISTRO="debian"
elif command -v dnf &>/dev/null; then
  DISTRO="fedora"
  warn "dnf detected — most installs will work but some steps assume apt/Debian"
else
  DISTRO="unknown"
  warn "Unknown package manager — proceeding, but package installs may fail"
fi

log "Mode: $MODE | Arch: $ARCH | Distro: $DISTRO"

# ---------------------------------------------------------------------------
# 1. SYSTEM PACKAGES
# ---------------------------------------------------------------------------

log "Installing system packages..."

if [[ "$DISTRO" == "debian" ]]; then
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

  if [[ "$MODE" == "wsl" ]]; then
    sudo apt-get install -y --no-install-recommends \
      wslu \
      libsecret-tools \
      libsecret-1-dev
  fi
elif [[ "$DISTRO" == "fedora" ]]; then
  sudo dnf check-update -q || true
  sudo dnf install -y \
    gcc gcc-c++ make \
    curl wget git \
    git-delta \
    unzip zip jq \
    fd-find ripgrep fzf bat \
    tmux zsh stow \
    sqlite \
    ca-certificates gnupg \
    python3 python3-pip \
    direnv tree htop
fi

success "System packages installed"

# ---------------------------------------------------------------------------
# 1b. ETERNALTERMINAL (et) — local client
# ---------------------------------------------------------------------------

log "Installing EternalTerminal (et)..."
if command -v et &>/dev/null; then
  success "et already installed: $(et --version 2>/dev/null | head -1)"
else
  if [[ "$DISTRO" == "fedora" ]]; then
    sudo dnf install -y et && success "et installed" || warn "et install failed"
  elif [[ "$DISTRO" == "debian" ]]; then
    sudo add-apt-repository -y ppa:jgmath2000/et
    sudo apt-get update -qq
    sudo apt-get install -y et && success "et installed" || warn "et install failed"
  else
    warn "et auto-install not supported on $DISTRO — install manually: https://eternalterminal.dev"
  fi
fi

# ---------------------------------------------------------------------------
# 2. NEOVIM — install latest stable from GitHub
# ---------------------------------------------------------------------------

log "Installing Neovim..."

NVIM_VERSION="stable"
NVIM_URL="https://github.com/neovim/neovim/releases/${NVIM_VERSION}/download/nvim-linux-${NVIM_ARCH}.tar.gz"

if ! nvim --version &>/dev/null || [[ "$(nvim --version | head -1)" < "NVIM v0.10" ]]; then
  curl -sL "$NVIM_URL" -o /tmp/nvim.tar.gz
  sudo tar -C /opt -xzf /tmp/nvim.tar.gz
  sudo ln -sf "/opt/nvim-linux-${NVIM_ARCH}/bin/nvim" /usr/local/bin/nvim
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
  if [[ "$DISTRO" == "debian" ]]; then
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc \
      | sudo gpg --dearmor -o /etc/apt/keyrings/gierens.gpg
    echo "deb [signed-by=/etc/apt/keyrings/gierens.gpg] http://deb.gierens.de stable main" \
      | sudo tee /etc/apt/sources.list.d/gierens.list
    sudo chmod 644 /etc/apt/keyrings/gierens.gpg /etc/apt/sources.list.d/gierens.list
    sudo apt-get update -qq && sudo apt-get install -y eza
    success "Eza installed"
  elif [[ "$DISTRO" == "fedora" ]]; then
    sudo dnf install -y eza
    success "Eza installed"
  else
    warn "eza: no package source configured for $DISTRO — install manually: https://github.com/eza-community/eza/releases"
  fi
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
    "https://github.com/jesseduffield/lazygit/releases/latest/download/lazygit_${LAZYGIT_VERSION#v}_Linux_${LG_ARCH}.tar.gz"
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
  if [[ "$DISTRO" == "debian" ]]; then
    curl -Lo /tmp/delta.deb \
      "https://github.com/dandavison/delta/releases/latest/download/git-delta_${DELTA_VERSION}_${DEB_ARCH}.deb"
    sudo dpkg -i /tmp/delta.deb
    rm /tmp/delta.deb
  else
    # musl tarball uses raw arch name (x86_64 / aarch64)
    curl -Lo /tmp/delta.tar.gz \
      "https://github.com/dandavison/delta/releases/latest/download/delta-${DELTA_VERSION}-${ARCH}-unknown-linux-musl.tar.gz"
    tar -xzf /tmp/delta.tar.gz -C /tmp
    sudo mv "/tmp/delta-${DELTA_VERSION}-${ARCH}-unknown-linux-musl/delta" /usr/local/bin/
    rm -rf /tmp/delta.tar.gz "/tmp/delta-${DELTA_VERSION}-${ARCH}-unknown-linux-musl"
  fi
  success "Delta installed"
else
  success "Delta already installed"
fi

# ---------------------------------------------------------------------------
# 10. WIN32YANK — WSL2 clipboard bridge for Neovim (WSL only)
# ---------------------------------------------------------------------------

if [[ "$MODE" == "wsl" ]]; then
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
fi

# ---------------------------------------------------------------------------
# 11. GITHUB CLI
# ---------------------------------------------------------------------------

log "Installing GitHub CLI..."
if ! command -v gh &>/dev/null; then
  if [[ "$DISTRO" == "debian" ]]; then
    curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
    sudo apt-get update -qq && sudo apt-get install -y gh
    success "GitHub CLI installed"
  elif [[ "$DISTRO" == "fedora" ]]; then
    sudo dnf install -y 'dnf-command(config-manager)' 2>/dev/null || true
    sudo dnf config-manager --add-repo https://cli.github.com/packages/rpm/gh-cli.repo
    sudo dnf install -y gh
    success "GitHub CLI installed"
  else
    warn "GitHub CLI: unsupported distro — install manually from https://github.com/cli/cli/releases"
  fi
else
  success "GitHub CLI already installed"
fi

# ---------------------------------------------------------------------------
# 12. DOCKER
# ---------------------------------------------------------------------------

if ! command -v docker &>/dev/null; then
  if [[ "$MODE" == "wsl" ]]; then
    log "Docker not found. Install Docker Desktop for Windows with WSL2 integration."
    log "See: https://docs.docker.com/desktop/wsl/"
  else
    log "Installing Docker CE..."
    if [[ "$DISTRO" == "debian" ]]; then
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg \
        | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" \
        | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
      sudo apt-get update -qq && sudo apt-get install -y docker-ce docker-ce-cli containerd.io
      sudo usermod -aG docker "$USER"
      success "Docker CE installed (re-login for docker group to take effect)"
    elif [[ "$DISTRO" == "fedora" ]]; then
      sudo dnf -y install dnf-plugins-core
      sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
      sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      sudo systemctl enable --now docker
      sudo usermod -aG docker "$USER"
      success "Docker CE installed (re-login for docker group to take effect)"
    else
      warn "Docker auto-install only supported on Debian/Ubuntu/Fedora — install manually"
    fi
  fi
else
  success "Docker available: $(docker --version)"
fi

# ---------------------------------------------------------------------------
# 13. TPM — tmux plugin manager (plugins installed after dotfiles are linked)
# ---------------------------------------------------------------------------

log "Installing tmux plugin manager (TPM)..."
if [[ ! -d "$HOME/.tmux/plugins/tpm" ]]; then
  git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
  success "TPM cloned"
else
  success "TPM already installed"
fi

# Pre-install the plugins used by tmux.conf so persistence/copy/paste work
# immediately, even before the user presses prefix + I inside tmux.
log "Installing tmux plugins..."
mkdir -p ~/.tmux/plugins
for plugin in tmux-plugins/tmux-sensible tmux-plugins/tmux-resurrect tmux-plugins/tmux-continuum tmux-plugins/tmux-yank; do
  name="$(basename "$plugin")"
  if [[ ! -d "$HOME/.tmux/plugins/$name" ]]; then
    git clone "https://github.com/$plugin" "$HOME/.tmux/plugins/$name"
    success "$name installed"
  else
    success "$name already installed"
  fi
done

# ---------------------------------------------------------------------------
# 14. LOCALE — generate en_US.UTF-8 (prevents GTK/terminal locale warnings)
# ---------------------------------------------------------------------------

log "Configuring locale..."
if command -v locale-gen &>/dev/null; then
  if ! locale -a 2>/dev/null | grep -q "en_US.utf8"; then
    sudo locale-gen en_US.UTF-8
    sudo update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8
    success "Locale en_US.UTF-8 generated"
  else
    success "Locale already configured"
  fi
fi

# ---------------------------------------------------------------------------
# 14b. INOTIFY LIMITS — critical for Next.js / Vite file watching
# ---------------------------------------------------------------------------

log "Configuring inotify limits..."
INOTIFY_CONF="/etc/sysctl.d/99-inotify.conf"
if [[ ! -f "$INOTIFY_CONF" ]] || ! grep -q "524288" "$INOTIFY_CONF" 2>/dev/null; then
  cat <<'EOF' | sudo tee "$INOTIFY_CONF"
# Raise inotify limits for Next.js/Vite/TypeScript file watchers
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
# 15. INSTALL DOTFILES via symlinks
# ---------------------------------------------------------------------------

log "Linking dotfiles..."

# Create XDG directories
mkdir -p ~/.config ~/.local/bin ~/.local/share ~/.cache

cd "$DOTFILES_DIR"

# Link individual config directories as SYMLINKS — the repo is the single source
# of truth. ghostty is a client-side terminal: skip on server mode.
LINK_CONFIGS="nvim tmux zellij starship git"
[[ "$MODE" == "wsl" ]] && LINK_CONFIGS="$LINK_CONFIGS ghostty"
for dir in $LINK_CONFIGS; do
  if [[ -d "config/$dir" ]]; then
    if [[ -e "$HOME/.config/$dir" && ! -L "$HOME/.config/$dir" ]]; then
      mv "$HOME/.config/$dir" "$HOME/.config/$dir.bak.$(date +%Y%m%d-%H%M%S)"
      warn "Backed up existing ~/.config/$dir"
    fi
    ln -sfn "$DOTFILES_DIR/config/$dir" "$HOME/.config/$dir"
    success "Linked config/$dir -> repo"
  fi
done

# Link shell config based on user choice.
if [[ "$SHELL_CHOICE" == "bash" ]]; then
  for target in .bashrc .bash_profile; do
    if [[ -e "$HOME/$target" && ! -L "$HOME/$target" ]]; then
      mv "$HOME/$target" "$HOME/${target}.bak.$(date +%Y%m%d-%H%M%S)"
      warn "Backed up existing $target"
    fi
    ln -sfn "$DOTFILES_DIR/home/$target" "$HOME/$target"
    success "Linked home/$target -> repo"
  done
  if [[ -e "$HOME/.bashrc.d" && ! -L "$HOME/.bashrc.d" ]]; then
    mv "$HOME/.bashrc.d" "$HOME/.bashrc.d.bak.$(date +%Y%m%d-%H%M%S)"
    warn "Backed up existing ~/.bashrc.d"
  fi
  ln -sfn "$DOTFILES_DIR/home/.bashrc.d" "$HOME/.bashrc.d"
  success "Linked home/.bashrc.d -> repo"
elif [[ "$SHELL_CHOICE" == "zsh" ]]; then
  if [[ -e "$HOME/.zshrc" && ! -L "$HOME/.zshrc" ]]; then
    mv "$HOME/.zshrc" "$HOME/.zshrc.bak.$(date +%Y%m%d-%H%M%S)"
    warn "Backed up existing ~/.zshrc"
  fi
  ln -sfn "$DOTFILES_DIR/home/.zshrc" "$HOME/.zshrc"
  success "Linked home/.zshrc -> repo"
fi

# Other home files (git config, ignore rules)
for file in "$DOTFILES_DIR"/home/.gitconfig "$DOTFILES_DIR"/home/.gitignore_global; do
  [[ -f "$file" ]] || continue
  basename=$(basename "$file")
  if [[ -e "$HOME/$basename" && ! -L "$HOME/$basename" ]]; then
    cp "$HOME/$basename" "$HOME/${basename}.backup.$(date +%Y%m%d)"
    warn "Backed up existing $basename"
  fi
  ln -sf "$file" "$HOME/$basename"
done

# Starship reads ~/.config/starship.toml
ln -sf "$DOTFILES_DIR/config/starship/starship.toml" ~/.config/starship.toml

if [[ "$MODE" == "wsl" ]]; then
  # WSL FIX: node/npx are nvm lazy shell-functions, absent from the non-interactive
  # PATH that Claude Code / mcp-hub spawn with — so they fall back to the WINDOWS
  # node and break MCP (UNC banner corrupts the stdio stream). Symlink the Linux
  # toolchain into ~/.local/bin, which sits ahead of Windows node on PATH.
  NODE_BIN="$(ls -d "$HOME"/.nvm/versions/node/*/bin 2>/dev/null | tail -1)"
  if [[ -n "$NODE_BIN" && -x "$NODE_BIN/node" ]]; then
    for b in node npx npm mcp-hub; do
      [[ -e "$NODE_BIN/$b" ]] && ln -sf "$NODE_BIN/$b" "$HOME/.local/bin/$b"
    done
    success "Linked Linux node toolchain into ~/.local/bin (WSL non-interactive fix)"
  fi
fi

# Secrets are NOT in the repo. Seed the untracked secrets file on first install.
mkdir -p "$HOME/.config/zsh"
if [[ ! -f "$HOME/.config/zsh/secrets.zsh" ]]; then
  umask 077
  cat > "$HOME/.config/zsh/secrets.zsh" <<'SECRETS'
# Untracked secrets — sourced by ~/.zshrc. NEVER commit this file.
# export ANTHROPIC_API_KEY="sk-ant-..."   # avante + Claude
# export TAVILY_API_KEY="tvly-..."        # avante @web (https://app.tavily.com)
SECRETS
  chmod 600 "$HOME/.config/zsh/secrets.zsh"
  warn "Created ~/.config/zsh/secrets.zsh — add your API keys there"
fi

success "Dotfiles linked"

# ---------------------------------------------------------------------------
# 15b. TPM PLUGINS — install now that tmux config is linked
# ---------------------------------------------------------------------------

if [[ -f "$HOME/.tmux/plugins/tpm/bin/install_plugins" ]]; then
  log "Installing TPM plugins..."
  "$HOME/.tmux/plugins/tpm/bin/install_plugins" &>/dev/null \
    && success "TPM plugins installed" \
    || warn "TPM plugin install had issues — in tmux run: prefix+I"
fi

# ---------------------------------------------------------------------------
# 15c. USER SYSTEMD SERVICES — tmux + Zellij persistence
# ---------------------------------------------------------------------------

log "Linking user systemd units..."
mkdir -p "$HOME/.config/systemd/user"
for unit in zellij.service tmux.service tmux-snapshot.service tmux-snapshot.timer; do
  src="$DOTFILES_DIR/config/systemd/user/$unit"
  dst="$HOME/.config/systemd/user/$unit"
  if [[ -f "$src" ]]; then
    if [[ -e "$dst" && ! -L "$dst" ]]; then
      mv "$dst" "$dst.bak.$(date +%Y%m%d-%H%M%S)"
      warn "Backed up existing $dst"
    fi
    ln -sfn "$src" "$dst"
    success "Linked systemd unit: $unit"
  fi
done

if command -v systemctl >/dev/null 2>&1; then
  systemctl --user daemon-reload >/dev/null 2>&1 || true
  log "Enabling tmux + Zellij persistence services..."
  systemctl --user enable zellij.service tmux.service tmux-snapshot.timer >/dev/null 2>&1 \
    && success "Persistence services enabled" \
    || warn "Could not enable persistence services — enable manually with: systemctl --user enable tmux.service zellij.service tmux-snapshot.timer"
  log "Starting tmux + Zellij persistence services..."
  systemctl --user start tmux.service zellij.service tmux-snapshot.timer >/dev/null 2>&1 \
    && success "Persistence services started" \
    || warn "Could not start persistence services — start manually with: systemctl --user start tmux.service zellij.service tmux-snapshot.timer"
fi

# ---------------------------------------------------------------------------
# 15d. NEOVIM PLUGINS — deterministic install from lazy-lock.json
# Lazy auto-installs the *latest* commits on first launch; `restore` pins every
# plugin to the versions committed in lazy-lock.json for reproducible installs.
# ---------------------------------------------------------------------------

if command -v nvim &>/dev/null && [[ -f "$HOME/.config/nvim/lazy-lock.json" ]]; then
  log "Installing Neovim plugins at locked versions..."
  nvim --headless "+Lazy! install" "+Lazy! restore" +qa 2>/dev/null \
    || warn "Neovim plugin restore had issues — open nvim and run ':Lazy restore'"
  success "Neovim plugins installed from lazy-lock.json"
fi

# ---------------------------------------------------------------------------
# 16. CHANGE DEFAULT SHELL
# ---------------------------------------------------------------------------

TARGET_SHELL="$(which "$SHELL_CHOICE")"
if [[ "$SHELL" != "$TARGET_SHELL" ]]; then
  log "Setting $SHELL_CHOICE as default shell..."
  chsh -s "$TARGET_SHELL"
  success "Shell changed to $SHELL_CHOICE (restart shell to take effect)"
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
echo "Bootstrap complete! (mode: $MODE)"
echo "=============================================="
echo ""
echo "Next steps:"
if [[ "$MODE" == "wsl" ]]; then
  echo "1. Copy wsl/.wslconfig to C:\\Users\\<YourUser>\\.wslconfig"
  echo "2. Restart WSL: wsl --shutdown (from PowerShell)"
  echo "3. Open a new terminal — $SHELL_CHOICE will be your shell"
  echo "4. Start nvim — plugins pinned to lazy-lock.json"
  echo "5. Run: gh auth login"
  echo "6. Add API keys to ~/.config/zsh/secrets.zsh"
else
  echo "1. exec $SHELL_CHOICE  (or log out and back in for default shell)"
  echo "2. Start nvim — plugins pinned to lazy-lock.json"
  echo "3. Run: gh auth login"
  echo "4. Add API keys to ~/.config/zsh/secrets.zsh"
fi
echo ""
echo "Log saved to: $LOG_FILE"
