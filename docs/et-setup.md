# EternalTerminal (ET) + Tmux Setup

This environment uses **WezTerm** locally, **EternalTerminal** for the network
layer, and **Tmux** for session multiplexing and crash-resilient persistence.

## Why EternalTerminal instead of plain SSH or Mosh?

- **Persistent TCP sessions** that survive network changes, sleep/wake, and
  brief connectivity loss without disconnecting Tmux.
- **Native scrollback** and **mouse support** over the network, unlike Mosh's
  virtual terminal screen.
- Works exactly like SSH once connected: run `et user@host`, then start Tmux.

## Quick start

### 1. Install ET on both sides

On Fedora (client and server):

```bash
sudo dnf install et
```

ET uses **TCP port `2022`** by default. The server must accept traffic on that
port.

### 2. Set up the remote server

Copy and run the included script on each remote host:

```bash
scp ~/dotfiles/scripts/setup-et-server.sh remotehost:/tmp/
ssh remotehost 'bash /tmp/setup-et-server.sh'
```

The script installs `et`, opens `2022/tcp` in firewalld, and enables/starts the
`etserver` systemd service.

### 3. Connect from WezTerm

Two launcher keybindings are provided in `command-tower-wezterm`:

| Key | Action |
|-----|--------|
| `CTRL + Space` then `e` | Pick a predefined host and open ET + Tmux in a new tab. |
| `CTRL + Space` then `E` | Prompt for a custom host and open ET + Tmux in a new tab. |

Both run:

```bash
et <host> -c "tmux new-session -A -s main"
```

Or connect manually:

```bash
et user@remotehost
tmux new-session -A -s main
```

## Session persistence

Tmux is configured with **TPM**, **tmux-resurrect**, and **tmux-continuum**:

- Automatic environment snapshots every **15 minutes**.
- Automatic restore when the Tmux server starts.
- Clipboard env vars (`DISPLAY`, `WAYLAND_DISPLAY`, `SSH_AUTH_SOCK`, `XAUTHORITY`)
  are refreshed on re-attach so OSC 52 clipboard sync keeps working across ET
  reconnects.

After a reboot or `et` reconnect, your Tmux sessions come back automatically.

## Bash environment

The host/remote bash environment uses:

- `~/.bashrc` and `~/.bash_profile` with an early non-interactive exit guard to
  protect GDM/GNOME and cron.
- `PROMPT_COMMAND` appended as a Fedora array.
- Strict `[ -f ... ]` guards for Cargo, Atuin, and Nix initializers.
- Modular fragments loaded from `~/.bashrc.d/`.

These files are managed directly in `$HOME`, not symlinked from this repo, so
changes to them must be copied manually if you want them on another machine.

## Firewall / troubleshooting

- Verify `etserver` is listening: `sudo ss -tlnp | grep 2022`.
- Check service status: `sudo systemctl status et`.
- Confirm the client can reach the server: `et user@host` should drop you into a
  shell.
- If Tmux doesn't restore, run `prefix + I` to ensure TPM plugins are installed,
  then `prefix + C-r` to reload the config.
