# Workstation Setup Bundle

A single entrypoint that clones/updates all environment repos and applies them
in the correct order on a fresh local machine, laptop, WSL instance, or VPS.

## One-line install

```bash
bash <(curl -sS https://raw.githubusercontent.com/dporkka/dotfiles/main/scripts/setup-workstation.sh)
```

## Usage

```bash
bash ~/dotfiles/scripts/setup-workstation.sh [options]
```

| Option | Description |
|---|---|
| `--mode desktop\|server` | `desktop` applies GUI/WSL tweaks; `server` configures a headless VPS. |
| `--shell bash\|zsh` | Choose the default login shell. Prompted interactively if omitted. |
| `--with-runtimes` | Also run `dev-setup` to install Node, Go, Python, Rust, and LSPs. Requires `--shell zsh`. |
| `--help` | Show usage. |

### Examples

```bash
# Local Fedora laptop with bash
bash ~/dotfiles/scripts/setup-workstation.sh --mode desktop --shell bash

# Headless VPS with bash + EternalTerminal server
bash ~/dotfiles/scripts/setup-workstation.sh --mode server --shell bash

# Full developer box with zsh + language runtimes
bash ~/dotfiles/scripts/setup-workstation.sh --mode desktop --shell zsh --with-runtimes
```

## What it does

1. **Clones/updates repos** into `~/`:
   - `dotfiles` — main config (Neovim, Tmux, shell configs, scripts, systemd units)
   - `command-tower-wezterm` — WezTerm config
   - `linux-keyboard-setup` — GNOME keyboard tweaks (desktop only)
   - `dev-setup` — language runtimes + LSPs (only with `--with-runtimes`)

2. **Runs `dotfiles/scripts/bootstrap.sh`**:
   - Installs system packages (Fedora/Debian)
   - Installs EternalTerminal client (`et`)
   - Installs Neovim, Starship, Zoxide, eza, pnpm, nvm, uv, lazygit, delta, GitHub CLI
   - Installs Tmux Plugin Manager (TPM) and core plugins
   - Symlinks configs from the repo based on the chosen shell
   - Enables user systemd units for tmux persistence
   - Sets the chosen shell as default

3. **Links WezTerm config** from `~/wezterm-config` to `~/.config/wezterm`.

4. **Desktop extras**: applies the GNOME keyboard setup for mac-like shortcuts.

5. **Server extras**: runs `setup-et-server.sh` to install/enable EternalTerminal
   on the remote host (opens TCP port 2022, starts `etserver`).

6. **Optional runtimes**: runs `dev-setup/bootstrap-vps.sh` for mise, Node, Go,
   Python, Rust, and LSP tooling.

## Shell configs

The bundle versions shell configs from `dotfiles/home/`:

- **bash** — `.bashrc`, `.bash_profile`, and `.bashrc.d/*.sh`
- **zsh** — `.zshrc`

These are symlinked into `$HOME`, so editing the repo edits your live shell.

## After running

1. Restart your terminal or log out/in for the default-shell change.
2. Inside tmux, install TPM plugins: `prefix + I` (default prefix is `C-a`).
3. Run `gh auth login` if you use GitHub CLI.
4. Add API keys to `~/.config/zsh/secrets.zsh`.

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
