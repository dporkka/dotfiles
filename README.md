# AI-Native Developer Environment

A portable Neovim + tmux + Ghostty command center for large-scale TypeScript/Node.js
development with AI coding agents (Claude Code, avante.nvim) and a unified MCP toolset.

Runs on **WSL2**, **native Linux desktops**, **headless Linux VPS** (over SSH), and
**macOS** (with minor differences, all noted below). The repo is the single source of
truth: configs are **symlinked** into `~/.config`, so editing the repo edits your live setup.

---

## What's inside

| Layer | Tools |
|---|---|
| **Editor** | Neovim 0.11+ / LazyVim · blink.cmp · fzf-lua · oil.nvim · conform · gitsigns + lazygit + diffview · harpoon · flash |
| **AI in editor** | **avante.nvim** (Cursor-style, `<leader>a`) · **claudecode.nvim** (`<leader>k`) · **supermaven** ghost-text · **mcphub.nvim** (MCP tools for avante) |
| **AI in terminal** | Claude Code CLI · git-worktree + tmux agent isolation · `agent-session.sh` (pings you when an agent finishes) |
| **MCP** | One blueprint (`config/mcp/servers.json`) → both Claude Code *and* avante. 6 core local servers: filesystem, memory, sequential-thinking, fetch, git, time |
| **Multiplexer** | Zellij 0.44+ (primary) · tmux 3.x preserved for existing workflows — seamless `C-hjkl` nav across nvim splits ↔ tmux panes (vim-tmux-navigator) |
| **Terminal** | Ghostty (local machine only) |
| **Shell** | zsh + starship; secrets kept out of the repo |

---

## Prerequisites

The bootstrap installs most of these on Debian/Ubuntu. On other distros / macOS, install the equivalents.

**Core (all platforms):**
- Neovim **≥ 0.11**, tmux **≥ 3.2**, git, zsh
- **Node ≥ 18** (`nvm` or system) — needed for npx MCP servers, mcphub, Claude Code
- **`uv` / `uvx`** — runs the Python MCP servers (`curl -LsSf https://astral.sh/uv/install.sh | sh`)
- ripgrep (`rg`), `fd`, `fzf`, `jq`
- [Claude Code CLI](https://docs.claude.com/claude-code) — `npm i -g @anthropic-ai/claude-code` (or the installer)
- A **Nerd Font** in your *local* terminal (CaskaydiaCove is the default) — for icons

**Optional:** lazygit, bat, eza, direnv, docker.

---

## Install

```bash
# 1. Clone to ~/dotfiles (the path is assumed by the configs & scripts)
git clone https://github.com/dporkka/dotfiles ~/dotfiles

# 2. Bootstrap — installs packages, then SYMLINKS configs into ~/.config
#    (idempotent; backs up any existing real files to *.bak.<timestamp>)
bash ~/dotfiles/scripts/bootstrap.sh

# 3. Add your secrets (NEVER committed — see "Secrets" below)
$EDITOR ~/.config/zsh/secrets.zsh     # bootstrap seeds an empty template

# 4. Register the local MCP servers with Claude Code
bash ~/dotfiles/scripts/mcp-sync.sh

# 5. Reload + first-run plugin install
exec zsh
nvim --headless "+Lazy! sync" +qa     # installs plugins + the mcp-hub binary
```

Already have a clone and just want to (re)link configs without a full bootstrap:

```bash
bash ~/dotfiles/scripts/link-config.sh
```

> **The symlink model:** `~/.config/{nvim,tmux,ghostty}`, `~/.zshrc`, and `~/.config/starship.toml`
> are symlinks into this repo. Edit the repo, changes are live immediately — no copy/sync step.
> Live config follows the repo's **checked-out branch**, so keep `main` checked out for daily use.

---

## Nix + home-manager

This repo is also a Nix flake. It uses [home-manager](https://github.com/nix-community/home-manager) to install your daily tools and exposes reusable `devShells` for Go, Rust, Node/TypeScript, and Python projects.

### Why Nix?

- **Reproducible.** The exact same tools and versions install on every machine — your laptop, a VPS, WSL, or a fresh VM.
- **Declarative.** Your environment is code. Add a tool to `home.nix` or a shell to `shells.nix`, run one command, and it’s there.
- **Isolated dev shells.** Jump into a project and get only the toolchain it needs, without conflicting with your global packages or other projects.
- **Atomic rollbacks.** home-manager keeps generations. If an update breaks something, roll back in seconds.
- **No more install scripts.** Stop running `curl | bash` or manually juggling `fnm`, `mise`, `rustup`, and language servers. Nix provides them all.
- **Works alongside this repo.** Your existing shell configs (`~/.zshrc`, `~/.bashrc`, etc.) stay in place. The flake only adds packages.

### Quick start

1. **Install Nix** (single-user mode works on Fedora even with SELinux):
   ```bash
   sudo mkdir -m 0755 /nix && sudo chown $USER /nix
   sh <(curl -L https://nixos.org/nix/install) --no-daemon
   . ~/.nix-profile/etc/profile.d/nix.sh
   ```

2. **Enable flakes**:
   ```bash
   mkdir -p ~/.config/nix
   echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf
   ```

3. **Apply the home configuration**:
   ```bash
   cd ~/dotfiles
   nix run home-manager -- switch -b backup --flake .#$USER
   ```

4. **Enter a dev shell**:
   ```bash
   nix develop ~/dotfiles#default  # everyday CLI tools
   nix develop ~/dotfiles#go       # Go + gopls + delve + golangci-lint
   nix develop ~/dotfiles#rust     # Rust + cargo + clippy + rust-analyzer
   nix develop ~/dotfiles#node     # Node + TypeScript + biome + prettierd
   nix develop ~/dotfiles#python   # Python + uv + ruff + pyright + pytest
   nix develop ~/dotfiles#full     # all of the above combined
   ```

### What it manages

- **home-manager** installs common packages: `git`, `just`, `tmux`, `tmuxp`, `zellij`, `fzf`, `zoxide`, `starship`, `eza`, `bat`, `ripgrep`, `fd`, `jq`, `yq-go`, `delta`, `lazygit`, `gh`, `direnv`, `nix-direnv`, `nixfmt`, `uv`, `nodejs`, `go`, `rustc`, `cargo`, `neovim`, `wget`, `curl`, `tree`, `htop`, `btop`, `unzip`, `zip`.
- **Existing shell configs are preserved.** `~/.bashrc`, `~/.zshrc`, `~/.profile`, and `~/.bash_profile` are left untouched. `direnv` is installed but not auto-hooked, so add `eval "$(direnv hook zsh)"` (or `bash`) to your shell config if you want directory-local env loading.
- **Dev shells** give you project-specific toolchains without polluting the global environment. Use them for the repos that don’t have their own flake (or as a quick fallback).

### Everyday commands

```bash
# Re-apply after editing home.nix or shells.nix
cd ~/dotfiles
nix run home-manager -- switch -b backup --flake .#$USER

# Check the flake for errors without building anything
nix flake check --no-build

# Update all flake inputs to their latest versions
nix flake update

# See home-manager generations and roll back if needed
home-manager generations
home-manager switch --flake .#$USER --generation <id>
home-manager switch --rollback

# Use with existing per-project flakes
# beads_viewer and bifrost already have their own flake.nix files.
# Enter them directly:
cd ~/beads_viewer && nix develop   # Go dev shell for bv
cd ~/bifrost && nix develop        # Bifrost dev shell
```

### Customizing

- **Add a global package:** edit `home.nix`, add the package name inside `home.packages`, then re-run `home-manager switch`.
- **Add a dev shell:** edit `shells.nix`, create a new package list and add it to the output set, then `nix develop .#<name>`.
- **Pin/unpin nixpkgs:** change the `nixpkgs.url` in `flake.nix`. Run `nix flake update` to regenerate `flake.lock`.

### Files

| File | Purpose |
|---|---|
| `flake.nix` | Flake inputs, home-manager configuration, dev shell outputs |
| `home.nix` | User packages and basic home-manager settings |
| `shells.nix` | `default`, `go`, `rust`, `node`, `python`, `full` dev shells |
| `flake.lock` | Locked dependency versions |

---

## Documentation

- **[Zellij Setup Guide](docs/zellij.md)** — install, layouts, AI-agent workflows, key bindings, and migration tips from tmux.
- **[Zellij Cheatsheet](docs/zellij-cheatsheet.md)** — one-page command/key/layout reference.

---

## Secrets & API keys

**No secret ever lives in the repo.** Real values go in `~/.config/zsh/secrets.zsh`
(untracked, `chmod 600`), which `~/.zshrc` sources:

```bash
# ~/.config/zsh/secrets.zsh
export ANTHROPIC_API_KEY="sk-ant-..."   # avante.nvim + Claude
export TAVILY_API_KEY="tvly-..."        # optional: avante @web search
```

- `ANTHROPIC_API_KEY` is required for **avante** (Claude Code uses its own auth).
- `TAVILY_API_KEY` is optional; avante's `@web` silently no-ops without it.
- `.gitignore` blocks `**/secrets.zsh`, `*.local`, `.env*`. If you ever paste a key into a
  tracked file by mistake, treat it as compromised and **rotate it** — git history is forever.

---

## MCP servers (unified blueprint)

One file, `config/mcp/servers.json`, feeds **both** AI surfaces:

- **Claude Code** ← `scripts/mcp-sync.sh` registers every server at *user scope*
  (`claude mcp add-json --scope user`). Re-run after editing the blueprint.
- **avante.nvim** ← `mcphub.nvim` reads the same file and exposes the tools to avante.
  Open the hub with `:MCPHub` (UI: `R` restart, `ga` toggle auto-approve, `M` marketplace).

The 6 default servers (official `modelcontextprotocol/servers`):

| Server | Runtime | Purpose |
|---|---|---|
| filesystem | npx (Node) | read/write under `~/dev` |
| memory | npx (Node) | persistent knowledge graph |
| sequential-thinking | npx (Node) | structured reasoning |
| fetch | uvx (Python) | fetch & convert web pages |
| git | uvx (Python) | git ops (repo path per call) |
| time | uvx (Python) | time / timezone |

**Verify:** `claude mcp list` (all 6 should report *Connected*).

**Add a server:** edit `config/mcp/servers.json`, then `bash ~/dotfiles/scripts/mcp-sync.sh`
and `:MCPHub` → `R` in Neovim. Remote servers use `{"type":"http","url":...}`.

**Change the filesystem scope:** the blueprint uses `${HOME}/dev`; edit it if your code lives elsewhere.

---

## Key bindings

### tmux (prefix = `C-a`)

| Key | Action |
|---|---|
| `C-a \|` / `C-a -` | Split vertical / horizontal |
| `C-h/j/k/l` | Navigate panes **and** nvim splits (no prefix, seamless) |
| `C-a D / A / Q` | Dev / Agent (3-col) / Quad layout |
| `C-a a` | **Agent dashboard** — fzf every agent across sessions + live preview; Enter jumps |
| `C-a W` | **Spawn agent** in a new git worktree (prompts for branch) |
| `C-a f` | Project finder (fzf over `~/dev`, etc.) |
| `C-a g` | lazygit popup · `C-a t` shell popup |
| `C-a S` | Session switcher · `M-1..9` jump to window |
| `C-a r` | Reload config · `prefix + I/U` TPM install/update |
| `C-a R` | Reconcile tmux agent registry after a mass restore (resurrect/continuum) |

### Zellij (primary multiplexer)

| Key | Action |
|---|---|
| `Ctrl b` | Enter tmux-emulation mode (then `\|`, `-`, `c`, `hjkl`, etc.) |
| `Alt h/j/k/l` | Move focus between panes/tabs |
| `Alt n` | New pane · `Alt f` toggle floating panes |
| `Ctrl t` / `Ctrl p` / `Ctrl n` / `Ctrl o` | Tab / pane / resize / session mode |
| `Ctrl o` `w` | Session manager popup |
| `Alt a` | **Agent session manager** popup |
| `Alt Shift a` | **Spawn agent session** (prompts for name/agent) |
| `Alt w` | **Spawn agent worktree** (prompts for branch/base/agent) |
| `Alt d` | **Agent dashboard** — fzf over running Zellij agent sessions |
| `zellij --layout agent --session <name>` | Spawn an AI agent session layout |
| `zellij --layout dev` / `quad` | Dev or quad pane layout |

### Neovim (leader = `Space`)

**AI — Claude Code (`<leader>k`)**

| Key | Action |
|---|---|
| `<leader>kk` | Toggle Claude Code |
| `<leader>ks` | Send visual selection as context |
| `<leader>kf` / `<leader>kb` | Focus / add current buffer |
| `<leader>kr` / `<leader>kC` | Resume / continue session |
| `<leader>ka` / `<leader>kd` | Accept / deny a proposed diff (`:w`/`:q` also work) |
| `<leader>kc` | Copy AST context block (file + fenced code) to clipboard |

**AI — avante (`<leader>a`)**

| Key | Action |
|---|---|
| `<leader>aa` / `<leader>ae` | Ask / edit selection |
| `<leader>at` | Toggle sidebar · `<leader>aM` repomap |
| `<leader>ac` / `<leader>ao` | Switch to Sonnet / Opus |
| `@` (in sidebar) | Add file/symbol to context |
| `<Tab>` (insert) | Accept supermaven ghost suggestion |

**MCP:** `:MCPHub` · `:checkhealth mcphub`

**Navigation / Git / LSP / Terminal** (unchanged highlights):
`Space Space` files · `Space /` grep · `-` oil · `s` flash · `M-1..4` harpoon ·
`gd`/`gr`/`K` LSP · `Space ca`/`Space rn`/`Space cf` · `]h`/`[h` + `Space ghs` hunks ·
`Space gg` lazygit · `Space gd` diffview · `Space gm` review branch vs main · `` C-` `` float term.

---

## AI agent workflows

```bash
# Jump to / create a tmux session for a project
work ~/dev/myproject

# One command: git worktree + tmux session (agent/editor/review) + launch agent.
# Each agent gets its own branch & dir, so parallel agents never collide.
agent-worktree.sh feat/payments "add MFA to the login form"   # prompt is optional
#   ↳ also bound to  C-a W  (prompts for a branch).  --base <b> / --agent <cmd> to override.

# Just a worktree, no agent:   new-worktree.sh feat/x main
# Dedicated agent session (editor/watch/review), pings on process exit:
agent-session.sh refactor-auth claude

# Zellij equivalents (coexist with tmux):
zwork ~/dev/myproject                    # jump to / create a zellij session
zellij-agent-session.sh refactor-auth claude
zellij-agent-dashboard.sh                # fzf mission control for zellij agents
zellij-agent-worktree.sh feat/payments   # worktree + zellij session + agent
```

**Mission control — which agent needs me?**

- **`C-a a`** / **`Alt d`** → fzf dashboard of every agent window across *all* sessions, with a
  live pane preview; Enter jumps to it.
- Status bar shows **`⚡N waiting / ✓N done`** across all sessions; window tabs get
  ⚡/✓ glyphs.
- This state comes from **Claude Code hooks** (`Stop` / `Notification` /
  `UserPromptSubmit` → `scripts/agent-hook.sh` → tmux `@agent_state`), which also
  fire the desktop/WSL toast. `done` only toasts when you're *not* looking at that
  pane, so active pairing stays quiet.
- ⚠️ The hooks live in **`~/.claude/settings.json` — machine-local, NOT in this repo** —
  so re-add them after cloning onto a new machine.

**Persistence & resurrection**

- The unified registry is snapshotted with `agent-registry.sh snapshot` and stored under
  `~/.local/state/agents/snapshots/`. Restore with `agent-registry.sh restore latest` or
  relaunch dead sessions with `agent-registry.sh resurrect --dry-run` / `resurrect`.
- A shell hook (`scripts/agent-shell-hook.sh`) runs on every `precmd`/`chpwd` to keep
  registry worktree/branch metadata in sync. Set `AGENT_AUTO_RESURRECT=true` to
  automatically revive a dead agent session when you `cd` back into its worktree.

**Review** each agent's work in Neovim with **`Space gm`** → diffview of `main...HEAD`
(the whole branch diff), or open its `review` window.

---

## Platform notes

### WSL2 (Windows)

**Always develop in `~/dev`, never `/mnt/c/`.** The 9P filesystem is catastrophically slow
for metadata-heavy work:

| Operation | `~/dev` (ext4) | `/mnt/c/` (9P) |
|---|---|---|
| `git status` | ~50ms | ~5,000ms |
| `pnpm install` | ~30s | ~5min+ |
| HMR / inotify | native | broken |

- **`.wslconfig`** (`C:\Users\<you>\.wslconfig`): memory cap, `autoMemoryReclaim=gradual`,
  `networkingMode=mirrored`, `sparseVhd=true`. See `wsl/.wslconfig`. Apply: `wsl --shutdown`.
- **inotify limits** (bootstrap sets these): `fs.inotify.max_user_watches=524288` — the
  default 8192 breaks Next.js/Vite HMR.
- **Clipboard:** `clip.exe` / `win32yank.exe` bridge to Windows (tmux & nvim auto-detect WSL).
- **Node-on-PATH (important):** `node`/`npx` from `nvm` are lazy shell-functions absent from
  non-interactive PATH, so Claude Code / `mcp-hub` would otherwise fall back to **Windows** node
  and break MCP (a UNC banner corrupts the stdio stream). Bootstrap symlinks the Linux toolchain
  into `~/.local/bin` (ahead of Windows node on PATH) to fix this. Re-run after a node version
  change: `for b in node npx npm mcp-hub; do ln -sf "$(ls -d ~/.nvm/versions/node/*/bin|tail -1)/$b" ~/.local/bin/$b; done`

### Headless Linux VPS (over SSH)

- **Skip** all WSL steps and Ghostty (Ghostty is your *local* terminal; you SSH in with your
  local terminal + tmux).
- Install Node (nvm or `apt`/`dnf`), `uv` (for uvx MCP servers), ripgrep, fd, fzf, jq, Claude Code.
  System node is on PATH already, so the MCP blueprint works as-is.
- **Clipboard over SSH:** rely on **OSC52** — tmux has `set -g set-clipboard on`; use a terminal
  that supports OSC52 (most modern ones do) so yanks reach your local clipboard.
- **Persistent sessions:** `ssh server -t "tmux new-session -A -s main"`. Add to `~/.ssh/config`:
  `ControlMaster auto` + `ControlPersist 10m` for fast re-attach.
- Desktop notifications degrade gracefully: `notify.sh` falls back to the terminal bell when no
  GUI / `notify-send` is present.

### macOS

- Install deps with Homebrew (`brew install neovim tmux ripgrep fd fzf jq uv`).
- Clipboard works natively (`pbcopy`/`pbpaste`); the WSL `clip.exe` alias is harmless/unused.
- Skip WSL and (optionally) Ghostty if you use another terminal. Everything else is identical.

---

## Maintenance

```bash
# Edit a config — it's a symlink, so changes are live immediately. Then:
sync-dotfiles.sh "msg"      # commit + push the repo

# Update plugins / tools
nvim --headless "+Lazy! update" +qa
bash ~/dotfiles/scripts/mcp-sync.sh        # after editing the MCP blueprint

# Health
nvim --startuptime /tmp/nvim.log && tail -3 /tmp/nvim.log   # target <100ms
claude mcp list                                              # MCP server health
# inside nvim: :checkhealth  ·  :checkhealth mcphub  ·  :LspInfo  ·  :Mason
```

---

## Troubleshooting

**MCP server "Failed to connect"** — almost always node-on-PATH:
```bash
command -v npx        # must be a Linux/native npx (NOT /mnt/c/... on WSL)
claude mcp get filesystem
```
On WSL, ensure `~/.local/bin/{node,npx}` symlinks exist (see WSL notes). uvx servers
(fetch/git/time) failing instead means `uv` isn't installed.

**Neovim clipboard not working (WSL)** — `win32yank.exe -o` should echo back; re-run bootstrap.

**inotify ENOSPC** — `sudo sysctl fs.inotify.max_user_watches=524288`.

**LSP not starting** — `:LspInfo`, `:Mason` (install the server), `:LspLog`.

**tmux plugins missing** — `git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm`, then `prefix + I`.

**`<C-hjkl>` doesn't cross into tmux** — needs `vim-tmux-navigator` (installed by this config) *and*
the matching `is_vim` bindings in `tmux.conf` (already present). Reload tmux: `prefix + r`.

**A config change didn't take effect** — confirm it's symlinked: `readlink ~/.config/nvim`
should point into `~/dotfiles`. If not, run `link-config.sh`.
