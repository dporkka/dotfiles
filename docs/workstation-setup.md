# Workstation Setup Bundle

A single entrypoint that clones/updates all environment repos and applies them
in the correct order on a fresh local machine, laptop, WSL instance, or VPS.

> **Goal:** Go from "fresh VPS" to "AI agents coding in tmux" with one command.

---

## One-liner install

On a fresh Ubuntu 22.04+/Fedora 40+ machine:

```bash
bash <(curl -sS https://raw.githubusercontent.com/dporkka/dotfiles/main/scripts/setup-workstation.sh) --yes --mode server --shell bash
```

For a local desktop or WSL instance:

```bash
bash <(curl -sS https://raw.githubusercontent.com/dporkka/dotfiles/main/scripts/setup-workstation.sh) --yes --mode desktop --shell bash
```

The installer is **idempotent** and **checkpointed** — if it fails or is
interrupted, re-run the same command and it resumes from the last completed
phase.

---

## Usage

```bash
bash ~/dotfiles/scripts/setup-workstation.sh [options]
```

| Option | Description |
|---|---|
| `--mode desktop\|server` | `desktop` applies GUI/WSL tweaks; `server` configures a headless VPS. Auto-detected if omitted. |
| `--shell bash\|zsh` | Choose the default login shell. Defaults to `bash` in `--yes` mode. |
| `--with-runtimes` | Also run `dev-setup` to install Node, Go, Python, Rust, and LSPs. Requires `--shell zsh`. |
| `--with-hardening` | Run VPS hardening (swap, kernel tuning, SSH hardening, fail2ban). Server mode only. |
| `--yes` | Skip interactive prompts and use safe defaults. |
| `--skip-preflight` | Skip system validation (not recommended). |
| `--force` | Ignore checkpoint state and rerun all phases. |
| `--help` | Show usage. |

### Examples

```bash
# Local Fedora laptop with bash
bash ~/dotfiles/scripts/setup-workstation.sh --mode desktop --shell bash

# Headless VPS with bash + EternalTerminal/Mosh server + hardening
bash ~/dotfiles/scripts/setup-workstation.sh --mode server --shell bash --with-hardening

# Full developer box with zsh + language runtimes
bash ~/dotfiles/scripts/setup-workstation.sh --mode desktop --shell zsh --with-runtimes
```

---

## 13 steps from laptop to agents coding

1. **Rent a VPS** with Ubuntu 22.04+ or Fedora 40+, 4 GB RAM minimum, 10 GB free disk.
2. **SSH into the VPS** as a non-root user with `sudo` access.
3. **Run the one-liner** above.
4. **Preflight checks** run automatically (OS, RAM, disk, network, package locks).
5. **Repos clone** into `~/`: `dotfiles`, `command-tower-wezterm`, `linux-keyboard-setup`, and optionally `dev-setup`.
6. **Bootstrap** installs packages: Neovim, tmux, Tmux Plugin Manager, fzf, ripgrep, fd, lazygit, delta, gh, uv, pnpm, Node, Starship, eza, zoxide, EternalTerminal, Mosh, and more.
7. **Configs are symlinked** so the repo is the single source of truth.
8. **WezTerm config** is linked from `~/wezterm-config` to `~/.config/wezterm`.
9. **Desktop extras** apply GNOME keyboard shortcuts (desktop only).
10. **Server extras** install/enable EternalTerminal server on TCP `2022`.
11. **Optional hardening** adds swap, kernel tuning, SSH pubkey-only auth, and fail2ban.
12. **Optional runtimes** install mise-style language toolchains and LSPs via `dev-setup`.
13. **Verify** with `dotfiles-doctor` and connect with WezTerm `LEADER + e` / `LEADER + m`.

---

## What it does

1. **Clones/updates repos** into `~/`:
   - `dotfiles` — main config (Neovim, Tmux, shell configs, scripts, systemd units)
   - `command-tower-wezterm` — WezTerm config
   - `linux-keyboard-setup` — GNOME keyboard tweaks (desktop only)
   - `dev-setup` — language runtimes + LSPs (only with `--with-runtimes`)

2. **Runs `dotfiles/scripts/bootstrap.sh`**:
   - Installs system packages (Fedora/Debian)
   - Installs EternalTerminal client (`et`) and Mosh
   - Installs Neovim, Starship, Zoxide, eza, pnpm, nvm, uv, lazygit, delta, GitHub CLI
   - Installs Tmux Plugin Manager (TPM) and core plugins
   - Symlinks configs from the repo based on the chosen shell
   - Enables user systemd units for tmux persistence
   - Sets the chosen shell as default

3. **Links WezTerm config** from `~/wezterm-config` to `~/.config/wezterm`.

4. **Desktop extras**: applies the GNOME keyboard setup for mac-like shortcuts.

5. **Server extras**: runs `setup-et-server.sh` to install/enable EternalTerminal
   on the remote host (opens TCP port 2022, starts `etserver`).

6. **Optional hardening**: runs `setup-vps-hardening.sh` to add swap, tune the
   kernel, harden SSH, and enable fail2ban.

7. **Optional runtimes**: runs `dev-setup/bootstrap-vps.sh` for language runtimes
   and LSP tooling.

---

## Shell configs

The bundle versions shell configs from `dotfiles/home/`:

- **bash** — `.bashrc`, `.bash_profile`, and `.bashrc.d/*.sh`
- **zsh** — `.zshrc`

These are symlinked into `$HOME`, so editing the repo edits your live shell.

### `.bashrc.d` fragments

| File | Purpose |
|---|---|
| `01-aliases.sh` | Standard navigation/git/system aliases |
| `02-runtimes.sh` | PATH setup for Go, NVM, pnpm, FZF, Atuin, Starship |
| `03-agents.sh` | Conditional launchers for Claude Code, Codex, Aider, Antigravity |

---

## After running

1. Restart your terminal or log out/in for the default-shell change.
2. Inside tmux, install TPM plugins: `prefix + I` (default prefix is `C-a`).
3. Run `gh auth login` if you use GitHub CLI.
4. Add API keys to `~/.config/zsh/secrets.zsh`.
5. Run `dotfiles-doctor` to verify the installation.
6. Run `dotfiles-info` for a quick status overview.

---

## Connecting to a remote server

From WezTerm:

- `LEADER + e` — pick a predefined ET host and open ET + Tmux in a new tab.
- `LEADER + E` — prompt for a custom ET host.
- `LEADER + m` — pick a predefined Mosh host and open Mosh + Tmux in a new tab.
- `LEADER + M` — prompt for a custom Mosh host.

Or manually:

```bash
# EternalTerminal (TCP)
et user@host -c "tmux new-session -A -s main"

# Mosh (UDP roaming)
mosh user@host -- tmux new-session -A -s main
```

See also: [EternalTerminal + Mosh + Tmux Setup](et-setup.md).

---

## Project scaffolding

Create a new project with an `AGENTS.md` template, optional tmuxp session, and
optional Claude Code settings:

```bash
newproj myapp --stack node --tmuxp --claude
```

---

## Health and maintenance

```bash
# Diagnose the installation
dotfiles-doctor

# Show a quick status overview
dotfiles-info

# Re-apply just the config symlinks
bash ~/dotfiles/scripts/link-config.sh

# Update Neovim plugins
nvim --headless "+Lazy! update" +qa

# Re-register MCP servers after editing the blueprint
bash ~/dotfiles/scripts/mcp-sync.sh
```
