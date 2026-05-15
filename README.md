# AI-Native Developer Environment

WSL2 + Neovim + tmux command center for large-scale TypeScript/Node.js development with AI coding agents.

## Architecture

```
Windows 11
└── WSL2 Ubuntu 26.04
    ├── tmux (session orchestrator)
    │   ├── project sessions (one per repo/feature)
    │   │   ├── window: editor (nvim)
    │   │   ├── window: agent (claude/aider)
    │   │   └── window: dev (server/tests/logs)
    │   └── persistent across disconnects
    ├── Neovim 0.11+ with LazyVim
    │   ├── LSP (vtsls, pyright, lua_ls, ...)
    │   ├── blink.cmp (completion)
    │   ├── fzf-lua (search)
    │   ├── oil.nvim (files)
    │   ├── conform.nvim (format)
    │   └── gitsigns + lazygit + diffview
    ├── AI tooling
    │   ├── Claude Code CLI
    │   ├── Aider
    │   └── git worktrees (agent isolation)
    └── ~/dev/
        ├── project-a/          (main worktree)
        ├── project-a-feat-x/   (agent worktree)
        └── project-b/
```

## Why Linux FS (~/dev, NOT /mnt/c/)

This is the most important performance decision in the setup:

| Operation | ~/dev (ext4) | /mnt/c/ (9P filesystem) |
|-----------|-------------|------------------------|
| `git status` | ~50ms | ~5,000ms |
| `pnpm install` | ~30s | ~5min+ |
| `next dev` HMR | <1s | 5-30s |
| inotify file watching | native | broken |
| Docker bind mounts | fast | very slow |

**Never develop in /mnt/c/. Always develop in ~/dev.**

The WSL2 virtual filesystem (9P protocol) has severe overhead for:
- Metadata-heavy operations (node_modules has thousands of small files)
- inotify (file system events don't work reliably across the boundary)
- Any tool that stats files repeatedly (TypeScript, webpack, vite, jest)

## Installation

```bash
# 1. Clone dotfiles
git clone https://github.com/dporkka/dotfiles ~/dotfiles

# 2. Run bootstrap (idempotent, safe to re-run)
bash ~/dotfiles/scripts/bootstrap.sh

# 3. Copy WSL config to Windows (run in PowerShell)
# Copy-Item \\wsl.localhost\Ubuntu\home\dporkka\dotfiles\wsl\.wslconfig $env:USERPROFILE\.wslconfig
# wsl --shutdown

# 4. Apply system WSL config
sudo cp ~/dotfiles/wsl/wsl.conf /etc/wsl.conf
# wsl --shutdown (from PowerShell)

# 5. Set inotify limits
sudo cp /etc/sysctl.d/99-wsl-inotify.conf /etc/sysctl.d/  # created by bootstrap
sudo sysctl --system
```

## Directory Structure

```
~/
├── dev/                    # ALL development here — never /mnt/c/
│   ├── project-a/
│   ├── project-b/
│   └── project-c-feat-x/  # git worktrees live alongside main
├── dotfiles/               # this repo
├── .config/
│   ├── nvim/               # Neovim config
│   ├── tmux/               # tmux config
│   └── starship.toml
├── .local/
│   ├── bin/                # local binaries (win32yank.exe, etc.)
│   └── share/pnpm/         # pnpm global packages
└── .ssh/                   # SSH keys
```

## Tmux Workflow

### Sessions
One tmux session per project or feature. Sessions survive disconnects.

```bash
# Start working on a project
work ~/dev/myproject        # creates/attaches session named after dir

# Create a new worktree for agent work
new-worktree.sh feat/payments main  # creates worktree + tmux session

# Spawn a dedicated AI agent session
agent-session.sh refactor-auth claude
agent-session.sh add-stripe aider --model claude-opus-4-5
```

### Key Bindings (prefix = C-a)

| Key | Action |
|-----|--------|
| `C-a \|` | Split vertical |
| `C-a -` | Split horizontal |
| `C-a h/j/k/l` | Navigate panes |
| `C-h/j/k/l` | Navigate panes (no prefix, vim-aware) |
| `C-a D` | Dev layout (editor 70% + terminal 30%) |
| `C-a A` | Agent layout (3 columns) |
| `C-a Q` | Quad layout (4 panes) |
| `C-a S` | Session switcher |
| `C-a r` | Reload config |
| `M-1..9` | Jump to window 1-9 (no prefix) |
| `prefix+I` | Install TPM plugins |
| `prefix+U` | Update TPM plugins |

## Neovim Key Bindings

Leader = `Space`

### Navigation
| Key | Action |
|-----|--------|
| `Space Space` | Find files (fzf-lua) |
| `Space /` | Live grep |
| `Space fb` | Buffers |
| `Space fg` | Git files |
| `Space fr` | Recent files |
| `-` | File browser (oil.nvim) |
| `s` | Flash jump |
| `M-1..4` | Harpoon slots |
| `Space ha` | Add to harpoon |
| `Space hh` | Harpoon menu |

### LSP
| Key | Action |
|-----|--------|
| `gd` | Go to definition |
| `gr` | References |
| `gi` | Implementations |
| `K` | Hover docs |
| `Space ca` | Code actions |
| `Space rn` | Rename symbol |
| `Space cf` | Format |
| `[d / ]d` | Prev/next diagnostic |
| `Space cd` | Line diagnostics |

### Git
| Key | Action |
|-----|--------|
| `Space gg` | LazyGit |
| `Space gd` | Diffview (review agent changes) |
| `Space gh` | File history |
| `]h / [h` | Next/prev hunk |
| `Space ghs` | Stage hunk |
| `Space ghb` | Blame line |

### Terminal
| Key | Action |
|-----|--------|
| `` C-` `` | Float terminal |
| `Space tc` | Claude Code terminal |
| `Space th` | Horizontal terminal |
| `Space tv` | Vertical terminal |
| `Esc Esc` | Exit terminal mode |

## AI Agent Workflows

### Pattern 1: Claude Code in tmux pane
```bash
# In any tmux session, open a new window for Claude
C-a c           # new window
claude          # start interactive session

# Or use the alias
agent "implement the payment flow for Stripe"
```

### Pattern 2: Git Worktree + Isolated Agent
```bash
# Main branch stays clean while agent works on feature
new-worktree.sh feat/user-dashboard main

# Agent works in the worktree session
# You can review progress without interrupting the agent:
tmux attach -t myproject-feat-user-dashboard
# Switch to 'watch' window to see git status
# Switch to 'review' window to run: git diff | nvim -R -
```

### Pattern 3: Multiple Parallel Agents
```bash
# Each agent gets its own session + worktree
agent-session.sh feat-a claude    # session: feat-a-20240115-143022
agent-session.sh feat-b claude    # session: feat-b-20240115-143045
agent-session.sh feat-c aider     # session: feat-c-20240115-143050

# Review all active agents
tmux ls | grep -E 'feat-'

# Check what any agent changed
tmux attach -t feat-a-20240115-143022
# switch to 'review' window
git diff --stat
```

### Pattern 4: Aider with architect mode
```bash
# For complex multi-file refactors
cd ~/dev/myproject
aider --model claude-opus-4-5 --architect \
  src/features/auth/ \
  src/lib/supabase/ \
  tests/auth/
```

### Reviewing Agent Output in Neovim
```
Space gd          → diffview (see all changed files)
Space gh          → file history
Space /           → grep for specific patterns the agent introduced
Space fD          → workspace diagnostics (see TypeScript errors)
```

## WSL2 Optimizations

### .wslconfig (C:\Users\<You>\.wslconfig)
```ini
[wsl2]
memory=8GB          # cap RAM usage
processors=8        # leave 2 for Windows
swap=0              # Linux manages its own swap

[experimental]
autoMemoryReclaim=gradual   # return freed RAM to Windows
networkingMode=mirrored     # consistent IP, VPN compat
dnsTunneling=true
sparseVhd=true              # VHD grows on demand
```

### inotify (set by bootstrap.sh)
```bash
# /etc/sysctl.d/99-wsl-inotify.conf
fs.inotify.max_user_watches=524288   # default 8192 kills Next.js HMR
fs.inotify.max_user_instances=512
```

### Node.js Performance
```bash
# pnpm is faster than npm in WSL2 (fewer filesystem operations)
# pnpm uses hardlinks; node_modules is always in ~/dev (ext4)

# Set pnpm store inside WSL FS (default is fine)
pnpm config set store-dir ~/.local/share/pnpm/store

# Increase Node.js heap for large TS monorepos
export NODE_OPTIONS="--max-old-space-size=8192"
```

### Clipboard
win32yank.exe bridges Neovim's clipboard to Windows. Installed by bootstrap.sh.

If you see clipboard issues:
```bash
# Test
echo "hello" | win32yank.exe -i
win32yank.exe -o  # should print "hello"
```

### SSH Keys
Keep SSH keys in WSL, not on the Windows FS:
```bash
mkdir -p ~/.ssh && chmod 700 ~/.ssh
# Generate key
ssh-keygen -t ed25519 -C "davidporkka@gmail.com"
# Add to agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
# Add public key to GitHub
gh auth login
# Or: cat ~/.ssh/id_ed25519.pub | clip.exe
```

## Remote SSH Workflow

```bash
# ~/.ssh/config
Host myserver
    HostName 1.2.3.4
    User ubuntu
    IdentityFile ~/.ssh/id_ed25519
    ServerAliveInterval 60
    ServerAliveCountMax 3
    ControlMaster auto
    ControlPath ~/.ssh/cm/%r@%h:%p
    ControlPersist 10m
    # ControlPersist keeps the connection alive for 10 min
    # so you can re-attach without re-authenticating
```

```bash
# Install dotfiles on remote server
ssh myserver "bash <(curl -sL https://raw.githubusercontent.com/dporkka/dotfiles/main/scripts/bootstrap-minimal.sh)"

# Work remotely with persistent session
ssh myserver -t "tmux new-session -A -s main"
```

## Monorepo Patterns

### TypeScript path aliases
LazyVim's vtsls config sets `autoUseWorkspaceTsdk=true`, which means it reads the workspace TypeScript version and tsconfig. No manual setup needed.

For path aliases in a turborepo/nx monorepo, vtsls resolves them via `tsconfig.json` paths automatically.

### pnpm workspace
```bash
# From any package in the workspace
pnpm --filter @myapp/web dev
pnpm --filter @myapp/api test

# Run across all packages
pnpm -r build
pnpm -r lint
```

### TypeScript performance in large repos
If LSP is slow, add to tsconfig.json:
```json
{
  "compilerOptions": {
    "incremental": true,
    "tsBuildInfoFile": ".tsbuildinfo"
  },
  "exclude": ["node_modules", "dist", ".next"]
}
```

## Maintenance

### Update everything
```bash
# Neovim plugins
nvim --headless -c "Lazy update" -c "qa"

# System packages
sudo apt update && sudo apt upgrade -y

# pnpm global tools
pnpm update -g

# Dotfiles
sync-dotfiles.sh
```

### Backup
Dotfiles are the backup. The bootstrap.sh script rebuilds the environment from scratch.

For project data, use git. For DB data, use pg_dump scripts or Supabase backups.

### Health checks
```bash
nvim --startuptime /tmp/nvim-startup.txt && tail -5 /tmp/nvim-startup.txt
# Target: <100ms total

tmux info | grep -i version

# LSP status (from inside nvim)
:LspInfo
:Mason
:checkhealth
```

## Troubleshooting

### Neovim clipboard not working
```bash
ls -la ~/.local/bin/win32yank.exe  # should exist
win32yank.exe -o  # should work
# If not: re-run bootstrap.sh or install manually
```

### file watcher limit errors (ENOSPC)
```bash
cat /proc/sys/fs/inotify/max_user_watches  # should be 524288
sudo sysctl fs.inotify.max_user_watches=524288
```

### LSP not starting
```bash
# In nvim
:LspInfo
:Mason   # check if server is installed
:LspLog  # check for errors
# Common fix: :MasonInstall typescript-language-server
```

### tmux plugins not installed
```bash
# Install TPM first
git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm
# Then in tmux: prefix+I
```

### WSL2 slow / high memory
```bash
# Check WSL memory
free -h
# Check what's using it
ps aux --sort=-%mem | head -20
# Force memory reclaim
echo 1 | sudo tee /proc/sys/vm/drop_caches
# Ensure .wslconfig has memory limit set
```

### pnpm install hanging in WSL2
```bash
# Ensure you're NOT in /mnt/c/
pwd  # must start with /home/

# Clear pnpm cache if corrupted
pnpm store prune
```

### Docker Desktop not connecting
```bash
# Ensure Docker Desktop WSL2 integration is enabled:
# Docker Desktop → Settings → Resources → WSL Integration → Enable for Ubuntu
docker info  # should show server info
```
