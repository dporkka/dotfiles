# EternalTerminal (ET) + Mosh + Tmux Setup

This environment uses **WezTerm** locally, **Tmux** for session multiplexing, and
**either EternalTerminal (ET) or Mosh** for the network layer. Both network tools
survive reconnects and sleep/wake, so your remote sessions stay alive across
flaky networks.

| Network layer | Transport | Best for |
|---|---|---|
| **EternalTerminal** | TCP (port `2022`) | Native scrollback, mouse support, and exact terminal emulation over the network. |
| **Mosh** | UDP (ports `60000-61000`) | Rapid roaming between networks, high-latency links, and intermittent connectivity. |

Choose whichever fits the link. The WezTerm config provides launchers for both.

## Quick start

### 1. Install the local client

On Fedora:

```bash
sudo dnf install et mosh tmux
```

On Debian/Ubuntu:

```bash
sudo add-apt-repository -y ppa:jgmath2000/et
sudo apt-get update
sudo apt-get install -y et mosh tmux
```

### 2. Set up the remote server

Pick a network layer and run the matching script on the remote host:

**EternalTerminal:**

```bash
scp ~/dotfiles/scripts/setup-et-server.sh remotehost:/tmp/
ssh remotehost 'bash /tmp/setup-et-server.sh'
```

The script installs `et`, opens TCP `2022` in firewalld, and enables/starts the
`etserver` systemd service.

**Mosh:**

```bash
scp ~/dotfiles/scripts/setup-mosh-server.sh remotehost:/tmp/
ssh remotehost 'bash /tmp/setup-mosh-server.sh'
```

The script installs `mosh` (which provides `mosh-server`), opens UDP
`60000-61000` in firewalld, and verifies the install.

### 3. Connect from WezTerm

The leader key is `CTRL + Space`.

| Key | Action |
|-----|--------|
| `LEADER + e` | Pick a predefined ET host and open ET + Tmux in a new tab. |
| `LEADER + E` | Prompt for a custom ET host and open ET + Tmux in a new tab. |
| `LEADER + m` | Pick a predefined Mosh host and open Mosh + Tmux in a new tab. |
| `LEADER + M` | Prompt for a custom Mosh host and open Mosh + Tmux in a new tab. |

Both launchers attach to (or create) a Tmux session named `main`:

```bash
# ET
et <host> -c "tmux new-session -A -s main"

# Mosh
mosh <host> -- tmux new-session -A -s main
```

Or connect manually:

```bash
# ET
et user@remotehost
tmux new-session -A -s main

# Mosh
mosh user@remotehost -- tmux new-session -A -s main
```

## Session persistence

Tmux is configured with **TPM**, **tmux-resurrect**, and **tmux-continuum**:

- Automatic environment snapshots every **15 minutes**.
- Automatic restore when the Tmux server starts.
- Clipboard env vars (`DISPLAY`, `WAYLAND_DISPLAY`, `SSH_AUTH_SOCK`, `XAUTHORITY`)
  are refreshed on re-attach so OSC 52 clipboard sync keeps working across
  reconnects.

After a reboot or network reconnect, your Tmux sessions come back automatically.

## Bash environment

The host/remote bash environment uses:

- `~/.bashrc` and `~/.bash_profile` with an early non-interactive exit guard to
  protect GDM/GNOME and cron.
- `PROMPT_COMMAND` appended as a Fedora array.
- Strict `[ -f ... ]` guards for Cargo, Atuin, and Nix initializers.
- Modular fragments loaded from `~/.bashrc.d/`.

These files live in `dotfiles/home/` and are **symlinked** into `$HOME` by
`bootstrap.sh` / `link-config.sh`, so they are versioned and follow the repo's
branch.

## Verification steps

After applying the bash configs, run these checks **before** closing your active
terminal windows.

### 1. Canary test — syntax sanity

Run a login shell in dry-exec mode to confirm `~/.bash_profile` and `~/.bashrc`
parse cleanly:

```bash
bash --login -c 'echo "login shell OK"'
```

If you see `login shell OK`, the interactive guards and sourcing loop are
healthy. If you see errors, fix them **now** while you still have open terminals.

### 2. Virtual console check — credential validation

Switch to a text console to verify GDM/GNOME login still works and your shell
starts correctly outside the GUI:

```bash
# Press Ctrl + Alt + F3 on the physical keyboard, log in, then run:
echo "console shell OK"

# Return to the graphical session with:
# Press Ctrl + Alt + F1  (or F2 on some systems)
```

If the text console login stalls or prints shell errors, the login-shell
profile is breaking GDM's credential validation. Re-check `~/.bash_profile` for
commands that block on user input or assume a GUI environment.

## Firewall / troubleshooting

### EternalTerminal

- Verify `etserver` is listening: `sudo ss -tlnp | grep 2022`.
- Check service status: `sudo systemctl status et`.
- Confirm the client can reach the server: `et user@host` should drop you into a
  shell.

### Mosh

- Verify `mosh-server` is installed: `mosh-server --version`.
- Confirm UDP `60000-61000` is open: `sudo firewall-cmd --list-ports`.
- Test a connection: `mosh user@host -- tmux new-session -A -s main`.

### Tmux

- If Tmux doesn't restore, run `prefix + I` to ensure TPM plugins are installed,
  then `prefix + C-r` to reload the config.
- Manual save/restore: `prefix + M-s` / `prefix + M-r`.
