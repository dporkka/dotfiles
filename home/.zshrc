# =============================================================================
# .zshrc — production zsh config for WSL2 AI-native dev environment
# =============================================================================

# ---------------------------------------------------------------------------
# PERFORMANCE: measure startup with: time zsh -i -c exit
# ---------------------------------------------------------------------------

# Skip global compinit — we call it once below with caching
skip_global_compinit=1

# ---------------------------------------------------------------------------
# CORE ENVIRONMENT
# ---------------------------------------------------------------------------

export EDITOR=nvim
export VISUAL=nvim
export PAGER=less
export LESS='-R --quit-if-one-screen --no-init'
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
export COLORTERM=truecolor  # 24-bit color for Neovim inside tmux

# XDG base dirs — many tools respect these; centralizes config
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_CACHE_HOME="$HOME/.cache"
export XDG_STATE_HOME="$HOME/.local/state"

# ---------------------------------------------------------------------------
# PATH — ordered by priority, no duplicates
# ---------------------------------------------------------------------------

typeset -U path  # zsh deduplication

path=(
  "$HOME/.local/bin"
  "$HOME/.cargo/bin"
  "$HOME/.kilo/bin"
  "/usr/local/bin"
  "/usr/bin"
  "/bin"
  "/usr/local/sbin"
  "/usr/sbin"
  "/sbin"
  $path
)

export PATH

# ---------------------------------------------------------------------------
# API KEYS — AI tooling
# ---------------------------------------------------------------------------

# Secrets (API keys) live OUTSIDE this tracked repo so they are never committed.
# Real values go in ~/.config/zsh/secrets.zsh (chmod 600, untracked). Set there:
#   ANTHROPIC_API_KEY  — avante + Claude   (https://console.anthropic.com/settings/keys)
#   TAVILY_API_KEY     — avante @web       (https://app.tavily.com)
[[ -f "$HOME/.config/zsh/secrets.zsh" ]] && source "$HOME/.config/zsh/secrets.zsh"

# ---------------------------------------------------------------------------
# WSL-SPECIFIC: open URLs in Windows browser
# ---------------------------------------------------------------------------

if grep -qi microsoft /proc/version 2>/dev/null; then
  export BROWSER="wslview"
  # wslview is part of wslu — install with: sudo apt install wslu
  # It opens URLs/files in the appropriate Windows application.

  # GPU/GL rendering for GUI apps launched from WSL (e.g. Ghostty).
  # WSL exposes the GPU via /dev/dxg + Mesa's d3d12 driver — not /dev/dri — so
  # Mesa's default Zink/DRI probe fails noisily ("ZINK: failed to choose pdev",
  # "egl: failed to create dri2 screen") before falling back. Pinning the WSL
  # D3D12 driver silences those libEGL warnings and keeps GPU acceleration.
  export MESA_LOADER_DRIVER_OVERRIDE=d3d12
  export GALLIUM_DRIVER=d3d12
  # If warnings persist, force software rendering instead (fine for a terminal):
  #   unset MESA_LOADER_DRIVER_OVERRIDE GALLIUM_DRIVER
  #   export LIBGL_ALWAYS_SOFTWARE=1
fi

# ---------------------------------------------------------------------------
# NODE / PNPM — lazy load NVM to avoid 200-500ms startup penalty
# ---------------------------------------------------------------------------

export NVM_DIR="$HOME/.nvm"
export PNPM_HOME="$HOME/.local/share/pnpm"

# Add pnpm to PATH immediately (fast, no shell overhead)
path=("$PNPM_HOME" $path)

# Lazy-load nvm: only loads when first invoked
# WHY: nvm.sh adds ~200-500ms to shell startup. This defers that cost.
__load_nvm() {
  unset -f nvm node npm npx
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"
}

nvm()  { __load_nvm; nvm "$@"; }
node() { __load_nvm; node "$@"; }
npm()  { __load_nvm; npm "$@"; }
npx()  { __load_nvm; npx "$@"; }

# If you use pnpm exclusively (recommended), you can call it directly without nvm.
# pnpm manages its own node via: pnpm env use --global lts

# ---------------------------------------------------------------------------
# PYTHON / UV — fast Python tooling
# ---------------------------------------------------------------------------

export UV_CACHE_DIR="$XDG_CACHE_HOME/uv"
# uv is already installed at ~/.kilo/bin area or ~/.local/bin

# ---------------------------------------------------------------------------
# DOCKER — WSL2 specific
# ---------------------------------------------------------------------------

# Docker Desktop for Windows integrates via its WSL2 backend.
# No DOCKER_HOST needed when using Docker Desktop's WSL integration.
# If using Docker Engine directly in WSL: uncomment below
# export DOCKER_HOST="unix:///var/run/docker.sock"

# ---------------------------------------------------------------------------
# HISTORY — tuned for multi-session dev workflows
# ---------------------------------------------------------------------------

HISTFILE="$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000

setopt HIST_IGNORE_DUPS       # don't record duplicate adjacent commands
setopt HIST_IGNORE_ALL_DUPS   # remove older duplicate entries from history
setopt HIST_FIND_NO_DUPS      # don't display duplicates when searching
setopt HIST_IGNORE_SPACE      # commands starting with space aren't recorded
setopt HIST_SAVE_NO_DUPS      # don't write duplicate entries to history file
setopt SHARE_HISTORY          # share history across all sessions immediately
setopt APPEND_HISTORY         # append rather than overwrite history file
setopt INC_APPEND_HISTORY     # write to history immediately, not on shell exit
setopt EXTENDED_HISTORY       # record timestamp and duration

# ---------------------------------------------------------------------------
# ZSH OPTIONS
# ---------------------------------------------------------------------------

setopt AUTO_CD              # type directory name to cd into it
setopt AUTO_PUSHD           # cd pushes onto directory stack
setopt PUSHD_IGNORE_DUPS    # no duplicate entries in dir stack
setopt PUSHD_SILENT         # don't print dir stack on pushd
setopt CORRECT              # suggest corrections for mistyped commands
setopt CORRECT_ALL          # suggest corrections for all arguments
setopt NO_BEEP              # silence
setopt INTERACTIVE_COMMENTS # allow # comments in interactive shell
setopt GLOB_DOTS            # include dotfiles in glob patterns
setopt EXTENDED_GLOB        # extended globbing patterns

# ---------------------------------------------------------------------------
# COMPLETION — cached for fast startup
# ---------------------------------------------------------------------------

autoload -Uz compinit

# Only regenerate completion cache once per day
() {
  local zcompdump="$XDG_CACHE_HOME/zsh/zcompdump-${ZSH_VERSION}"
  local -i stale=0
  if [[ -f "$zcompdump" && -n "$zcompdump"(#qN.mh+24) ]]; then
    stale=1
  fi
  mkdir -p "${zcompdump:h}"
  if (( stale )); then
    compinit -d "$zcompdump"
    compdump
  else
    compinit -C -d "$zcompdump"
  fi
}

# Completion styling
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%B%d%b'
zstyle ':completion:*:warnings' format 'No matches for: %d'
zstyle ':completion:*' use-cache yes
zstyle ':completion:*' cache-path "$XDG_CACHE_HOME/zsh/completion-cache"
mkdir -p "$XDG_CACHE_HOME/zsh"

# ---------------------------------------------------------------------------
# KEY BINDINGS — vi mode with emacs fallbacks for common ops
# ---------------------------------------------------------------------------

bindkey -e  # emacs bindings (easier for quick editing; switch to -v for vi mode)

bindkey '^[[A' history-search-backward  # up arrow: history search
bindkey '^[[B' history-search-forward   # down arrow: history search
bindkey '^R' history-incremental-search-backward
bindkey '^A' beginning-of-line
bindkey '^E' end-of-line
bindkey '^K' kill-line
bindkey '^U' backward-kill-line
bindkey '^W' backward-kill-word

# ---------------------------------------------------------------------------
# ALIASES — functional, not decorative
# ---------------------------------------------------------------------------

# Navigation
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias ~='cd ~'
alias dev='cd ~/dev'

# File listing — use eza if available, fall back to ls
if command -v eza &>/dev/null; then
  alias ls='eza --icons=never --group-directories-first'
  alias ll='eza -la --icons=never --group-directories-first --git'
  alias lt='eza --tree --icons=never --level=2'
  alias ltt='eza --tree --icons=never --level=3'
else
  alias ls='ls --color=auto --group-directories-first'
  alias ll='ls -lahF --color=auto'
fi

# Safety
alias rm='rm -i'
alias cp='cp -i'
alias mv='mv -i'

# fd (Ubuntu packages it as fdfind)
if command -v fdfind &>/dev/null && ! command -v fd &>/dev/null; then
  alias fd='fdfind'
fi

# Editor
alias v='nvim'
alias vi='nvim'

# Git
alias g='git'
alias gs='git status -sb'
alias ga='git add'
alias gaa='git add -A'
alias gc='git commit'
alias gcm='git commit -m'
alias gca='git commit --amend --no-edit'
alias gp='git push'
alias gpf='git push --force-with-lease'
alias gpl='git pull --rebase'
alias gf='git fetch --all --prune'
alias gl='git log --oneline --graph --decorate --all'
alias gll='git log --graph --decorate --all'
alias gd='git diff'
alias gds='git diff --staged'
alias gco='git checkout'
alias gb='git branch -vv'
alias gba='git branch -a'
alias gst='git stash'
alias gstp='git stash pop'
alias gcp='git cherry-pick'
alias grb='git rebase'
alias grbi='git rebase -i'
alias gwt='git worktree'
alias gwta='git worktree add'
alias gwtl='git worktree list'
alias gwtr='git worktree remove'

# tmux
alias ta='tmux attach -t'
alias tls='tmux ls'
alias tn='tmux new -s'
alias tk='tmux kill-session -t'

# zellij (coexists with tmux; use z-prefixed aliases)
if command -v zellij &>/dev/null; then
  alias za='zellij attach'
  alias zl='zellij list-sessions'
  alias zn='zellij --session'
  alias zk='zellij delete-session'
  alias zka='zellij delete-all-sessions'
  alias zsd='zellij-service.sh'
fi

# Docker
alias d='docker'
alias dc='docker compose'
alias dps='docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"'
alias dlogs='docker compose logs -f'
alias ddown='docker compose down'
alias dup='docker compose up -d'
alias dexec='docker compose exec'
alias dprune='docker system prune -f'

# Node / pnpm
alias pn='pnpm'
alias pni='pnpm install'
alias pnd='pnpm dev'
alias pnb='pnpm build'
alias pnt='pnpm test'
alias pnr='pnpm run'
alias pnx='pnpm exec'

# Process
alias ports='ss -tulpn'
alias myip='curl -s ifconfig.me'
alias path='echo $PATH | tr ":" "\n"'
alias reload='exec zsh'

# Clipboard (WSL)
alias pbcopy='clip.exe'
alias pbpaste='powershell.exe -command "Get-Clipboard"'

# Lazygit
alias lg='lazygit'

# ---------------------------------------------------------------------------
# FUNCTIONS
# ---------------------------------------------------------------------------

# Create directory and cd into it
mkcd() { mkdir -p "$1" && cd "$1"; }

# Git worktree quick-add: gwt-add <branch> [path]
gwt-add() {
  local branch="$1"
  local path="${2:-../$(basename $(git rev-parse --show-toplevel))-${branch}}"
  git worktree add "$path" -b "$branch" 2>/dev/null || git worktree add "$path" "$branch"
  echo "Worktree at: $path"
}

# Start a new tmux session for a project
work() {
  local session="${1:-$(basename $PWD)}"
  if tmux has-session -t "$session" 2>/dev/null; then
    tmux attach -t "$session"
  else
    tmux new-session -d -s "$session" -x "$(tput cols)" -y "$(tput lines)"
    tmux send-keys -t "$session" "cd ${2:-$PWD}" Enter
    tmux attach -t "$session"
  fi
}

# Quick Claude Code agent session in a new tmux window
agent() {
  local task="${1:-}"
  local window_name="agent-$(date +%H%M%S)"
  tmux new-window -n "$window_name"
  if [[ -n "$task" ]]; then
    tmux send-keys "claude --task '${task}'" Enter
  else
    tmux send-keys "claude" Enter
  fi
}

# Start a new zellij session for a project (mirrors work() for tmux)
zwork() {
  if ! command -v zellij &>/dev/null; then
    echo "zellij not found" >&2
    return 1
  fi
  local session="${1:-$(basename "$PWD")}"
  local cwd="${2:-$PWD}"
  if zellij list-sessions 2>/dev/null | grep -q "^${session} "; then
    zellij attach "$session"
  else
    cd "$cwd" && zellij --session "$session"
  fi
}

# Quick Claude Code agent session in a new zellij tab
zagent() {
  if ! command -v zellij &>/dev/null; then
    echo "zellij not found" >&2
    return 1
  fi
  local task="${1:-}"
  local tab_name="agent-$(date +%H%M%S)"
  if [[ -n "$task" ]]; then
    zellij run --name "$tab_name" -- claude --task "$task"
  else
    zellij run --name "$tab_name" -- claude
  fi
}

# Open file/URL from WSL in Windows
open() {
  if [[ -f "$1" ]]; then
    wslview "$1"
  elif [[ "$1" =~ ^https?:// ]]; then
    wslview "$1"
  else
    explorer.exe "$1" 2>/dev/null || wslview "$1"
  fi
}

# Show listening ports with process names
listening() {
  if command -v ss &>/dev/null; then
    ss -tulpn | grep LISTEN
  else
    netstat -tulpn 2>/dev/null | grep LISTEN
  fi
}

# Fast project switcher using fzf
proj() {
  local dir
  dir=$(find ~/dev -maxdepth 2 -type d -name ".git" 2>/dev/null \
    | sed 's|/.git||' \
    | fzf --height=40% --layout=reverse --prompt="project> ")
  [[ -n "$dir" ]] && cd "$dir"
}

# pnpm / node version check
nvmuse() {
  __load_nvm
  local version
  version=$(cat .nvmrc 2>/dev/null || cat .node-version 2>/dev/null)
  if [[ -n "$version" ]]; then
    nvm use "$version"
  else
    echo "No .nvmrc or .node-version found"
  fi
}

# ---------------------------------------------------------------------------
# TOOLS — initialize only what's fast
# ---------------------------------------------------------------------------

# fzf — instant (sources a small file)
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git --exclude node_modules'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git --exclude node_modules'
export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border --info=inline'

# zoxide — fast directory jumping (replaces z/autojump)
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# direnv — per-directory environment variables (fast: ~5ms)
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

# ---------------------------------------------------------------------------
# PROMPT — starship (precompiled binary, ~2ms overhead)
# ---------------------------------------------------------------------------

command -v starship &>/dev/null && eval "$(starship init zsh)"

# ---------------------------------------------------------------------------
# AGENT REGISTRY SHELL HOOKS
# Keep the unified agent registry in sync with the current shell context.
# precmd updates worktree/branch for the active tmux/Zellij session.
# chpwd offers to resurrect a dead agent session when you cd back into its
# worktree (set AGENT_AUTO_RESURRECT=true to resurrect automatically).
# ---------------------------------------------------------------------------

agent_precmd() { "$HOME/dotfiles/scripts/agent-shell-hook.sh" >/dev/null 2>&1 || true; }
agent_chpwd()  { "$HOME/dotfiles/scripts/agent-shell-hook.sh" >/dev/null 2>&1 || true; }

# Avoid duplicate registration if this file is re-sourced.
if (( ! ${precmd_functions[(I)agent_precmd]} )); then
  precmd_functions+=(agent_precmd)
fi
if (( ! ${chpwd_functions[(I)agent_chpwd]} )); then
  chpwd_functions+=(agent_chpwd)
fi

# ---------------------------------------------------------------------------
# LOCAL OVERRIDES — machine-specific config not in dotfiles
# ---------------------------------------------------------------------------

[[ -f ~/.zshrc.local ]] && source ~/.zshrc.local
