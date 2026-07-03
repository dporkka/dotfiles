# Zellij Setup Guide

Zellij is the primary terminal multiplexer in this dotfiles repo. It coexists with the existing tmux workflow — tmux key bindings and scripts are unchanged, so you can switch gradually or keep using tmux for legacy sessions.

## Why Zellij for AI agents?

- **Built-in layouts** — define an agent session as code (`agent.kdl`) instead of sending tmux commands.
- **Session serialization** — Zellij can restore pane contents after a detach/reattach or reboot.
- **Floating panes / popups** — agent dashboards and prompts feel like IDE overlays.
- **Better defaults** — mouse, scrollback, and pane frames work out of the box with less config.

---

## Install & first run

Zellij is installed at `~/.local/bin/zellij`. If it is missing on a new machine, the easiest path is the static release binary:

```bash
# Download latest musl binary (no glibc/OpenSSL dependency)
curl -LO https://github.com/zellij-org/zellij/releases/latest/download/zellij-x86_64-unknown-linux-musl.tar.gz
tar -xzf zellij-x86_64-unknown-linux-musl.tar.gz
mv zellij ~/.local/bin/
zellij --version
```

The dotfiles bootstrap also links the config:

```bash
bash ~/dotfiles/scripts/link-config.sh
```

Start Zellij:

```bash
zellij                    # new session with default layout
zellij attach <name>      # attach to existing session
zellij ls                 # list sessions
```

---

## Daily workflow

### Start a project session

```bash
zwork ~/dev/myproject
```

This function (defined in `~/.zshrc` / `~/.bashrc`) creates a session named after the project directory or attaches if it already exists.

### Start an AI agent session

```bash
# Dedicated agent session: agent pane + git watcher + review pane
zellij-agent-session.sh refactor-auth claude

# With extra args
zellij-agent-session.sh add-payments aider --model claude-opus-4-5
```

Each session is timestamped (`refactor-auth-20260702-143022`), isolated, and persists if you detach. The agent pane runs the chosen CLI; when it exits, `notify.sh` pings you.

### Start an agent in a git worktree

```bash
zellij-agent-worktree.sh feat/payments "add MFA to the login form"
```

This creates a new worktree, opens a Zellij session there, and launches the agent. Use this when you want several agents working in parallel on different branches without file-system collisions.

### Mission control: find the agent that needs you

```bash
zellij-agent-dashboard.sh
```

Or press `Alt + d` inside Zellij. This opens an fzf list of running agent sessions with a live tab preview; `Enter` attaches/switches to the selected session.

### Quick agent tab inside the current session

```bash
zagent "refactor the auth middleware"
```

This opens a new floating tab named `agent-HHMMSS` running `claude --task "..."` (or plain `claude` if no task is given).

---

## Key bindings

### Global (Zellij normal mode)

| Key | Action |
|---|---|
| `Alt + h/j/k/l` | Move focus left/down/up/right |
| `Alt + Left/Right` | Move focus or switch tab |
| `Alt + 1..9` | Jump to tab 1–9 |
| `Alt + n` | New pane |
| `Alt + f` | Toggle floating panes |
| `Alt + =/+` / `Alt + -` | Increase / decrease pane size |
| `Alt + [` / `Alt + ]` | Previous / next swap layout |
| `Ctrl + t` | Tab mode |
| `Ctrl + p` | Pane mode |
| `Ctrl + n` | Resize mode |
| `Ctrl + o` | Session mode |
| `Ctrl + g` | Lock mode (ignore all Zellij keys) |
| `Ctrl + q` | Quit Zellij |

### AI agent bindings

| Key | Action |
|---|---|
| `Alt + a` | Session manager popup |
| `Alt + d` | **Agent dashboard** (fzf over tmux + Zellij agents) |
| `Alt + Shift + a` | **Spawn new agent session** (prompt) |
| `Alt + w` | **Spawn new agent worktree** (prompt) |
| `Alt + r` | **List agents** from the unified registry |
| `Alt + Shift + r` | **Prune dead agents** from the registry |

### tmux emulation mode (`Ctrl + b`)

If your muscle memory is tmux, press `Ctrl + b` to enter tmux-emulation mode, then:

| Key | Action |
|---|---|
| `\|` | Split vertical |
| `-` | Split horizontal |
| `c` | New tab |
| `h/j/k/l` | Move focus |
| `n` / `p` | Next / previous tab |
| `z` | Toggle fullscreen pane |
| `x` | Close pane |
| `[` | Scroll mode |
| `a` | Agent dashboard |
| `A` | Spawn agent session |
| `W` | Spawn agent worktree |
| `d` | Detach |

---

## Layouts

Layouts live in `~/dotfiles/config/zellij/layouts/`.

### `agent.kdl`

```
agent (left 50%) | watch (top-right 25%) / review (bottom-right 25%)
```

- **agent**: runs `${ZELLIJ_AGENT_CMD:-claude}`.
- **watch**: polls `git status` and `git diff --stat` every 2 seconds.
- **review**: idle shell ready for `git diff`, `lazygit`, or `nvim`.

Use it directly:

```bash
zellij --layout agent --session my-agent
```

### `dev.kdl`

Editor / terminal split. Good for focused coding with a small terminal pane.

### `quad.kdl`

Four-pane layout: editor + tests + agent + logs. Useful for complex refactoring where you want to watch tests and agent output at the same time.

---

## Session persistence

Zellij is configured with:

```kdl
session_serialization true
serialize_pane_viewport true
```

This means:

- Detaching and re-attaching preserves scrollback.
- After a system restart, Zellij can restore sessions if your terminal emulator / systemd unit supports it.
- Background agent sessions survive accidental terminal closure.

### tmux persistence

tmux uses `tmux-resurrect` + `tmux-continuum` (managed by TPM). The companion script `scripts/tmux-agent-persistence.sh` snapshots the agent registry on every session change and reconciles it after a mass restore. After a reboot, attach tmux and press `C-a R` to clear stale PIDs and mark restored agent sessions as idle.

---

## Systemd service (user-local)

A user systemd unit keeps the Zellij server alive independently of any terminal window, so background agent sessions are not killed when you close a terminal or log out.

Install/link the unit (also done by `link-config.sh`):

```bash
zellij-service.sh install
```

Enable and start the service:

```bash
zellij-service.sh enable
zellij-service.sh start
```

Check status:

```bash
zellij-service.sh status
```

What it does:

- Runs a lightweight holder session named `zellij-daemon` using `config/zellij/layouts/daemon.kdl`.
- The holder session is **not** registered in the agent registry, so it does not appear in dashboards.
- If the Zellij server exits, the service restarts it (`Restart=on-failure`).
- On service stop, the holder session is cleaned up.

You can still use `zellij attach <session>` and all existing Zellij key bindings as usual.

---

## Unified agent registry

Every agent launcher registers its session in `~/.local/state/agents/registry/<session>.json`. This gives you one source of truth for agents across tmux and Zellij.

Why it helps:

- One dashboard (`C-a a` / `Alt+d`) lists **both** tmux and Zellij agents.
- State survives multiplexer restarts because it lives on disk.
- The tmux status bar counts waiting/done agents from both multiplexers.

Registry commands:

```bash
# List all agents
agent-registry.sh list

# JSON output for scripting
agent-registry.sh list --json

# Remove records for dead sessions
agent-registry.sh prune

# Manual state override
agent-registry.sh set-state <session> waiting

# Snapshots — save/restore the whole registry for persistence/resurrection
agent-registry.sh snapshot              # save a timestamped snapshot
agent-registry.sh list-snapshots        # show available snapshots
agent-registry.sh restore latest        # restore from the newest snapshot
agent-registry.sh restore <name>        # restore a named snapshot
agent-registry.sh resurrect --dry-run   # preview sessions that would be revived
agent-registry.sh resurrect             # relaunch dead agent sessions from latest snapshot
```

Fields stored per agent: `session`, `multiplexer`, `worktree`, `branch`, `base`, `agent_cmd`, `pid`, `state`, `started_at`, `updated_at`.

### Registry snapshots

Snapshots write the entire registry to `~/.local/state/agents/snapshots/<timestamp>.json`. They are the resurrection source of truth: even after a `prune`/`clear` or a multiplexer restart, you can restore records or relaunch dead sessions.

A good habit is to snapshot before rebooting or before a big prune:

```bash
agent-registry.sh snapshot pre-reboot
```

### Manual resurrection with agent-resurrect.sh

`scripts/agent-resurrect.sh` resurrects agents directly from the current registry records (no snapshot needed). It handles both tmux and Zellij, and both worktree agents and simple session agents:

```bash
# List dead-but-resurrectable agents
agent-resurrect.sh list

# Resurrect a specific agent by session name
agent-resurrect.sh my-session

# Preview what would be resurrected
agent-resurrect.sh all --dry-run

# Resurrect every eligible dead agent
agent-resurrect.sh all
```

The script preserves the original session name, re-creates the worktree if it is missing, and restores the agent pane + watcher + review layout for worktree sessions.

### Shell hooks

`scripts/agent-shell-hook.sh` is wired into `~/.zshrc` via `precmd` and `chpwd`. It:

- Updates the registry record for the current tmux/Zellij session when you change directory.
- Detects when you `cd` back into an agent worktree whose session is dead and prints a resurrection hint.
- Auto-resurrects dead sessions when `AGENT_AUTO_RESURRECT=true` is exported.

To enable automatic resurrection, add this to `~/.zshrc.local`:

```bash
export AGENT_AUTO_RESURRECT=true
```

## Agent state in the status bar

`scripts/agent-hook.sh` is called by Claude Code hooks (`Stop`, `Notification`, `UserPromptSubmit`). It:

- Renames the current Zellij tab with `⚡ waiting`, `• working`, or `✓ done` prefixes.
- Mirrors the state into the unified registry so the dashboard/status line stay in sync.
- Fires a desktop/WSL notification via `notify.sh` when an agent finishes, unless you are currently focused on it.

Wire the hooks in `~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": "bash $HOME/dotfiles/scripts/agent-hook.sh working",
    "Notification": "bash $HOME/dotfiles/scripts/agent-hook.sh waiting",
    "Stop": "bash $HOME/dotfiles/scripts/agent-hook.sh done"
  }
}
```

---

## Migration tips from tmux

- **Prefix**: tmux uses `C-a`; Zellij uses `Alt` chords plus a `Ctrl + b` tmux-emulation mode. You can run both side by side.
- **Sessions**: `tmux ls` → `zellij ls`; `tmux attach -t x` → `zellij attach x`.
- **Windows/tabs**: tmux windows ≈ Zellij tabs; tmux panes ≈ Zellij panes.
- **Copy mode**: tmux `prefix + [` → Zellij `Ctrl + s` (scroll mode). Use vi keys (`j/k`, `Ctrl+f/b`, `/` to search).
- **Reload config**: tmux `prefix + r` → Zellij config is read on startup; restart the session or edit the KDL and start a new session.

---

## Aliases & functions

Loaded from `~/.zshrc` / `~/.bashrc`:

```bash
za    # zellij attach
zl    # zellij list-sessions
zn    # zellij --session
zk    # zellij delete-session
zka   # zellij delete-all-sessions

zwork ~/dev/myproject   # project session
zagent "task"           # quick agent tab
```

---

## Troubleshooting

### Zellij says "Config file is well defined" but key bindings don't work

- Check that `~/.config/zellij` is symlinked: `readlink ~/.config/zellij`.
- If you are inside tmux or another multiplexer, `Alt` keys may be intercepted. Run Zellij from a plain terminal.
- Some terminal emulators swallow `Alt + Shift + a`; use the tmux-emulation path (`Ctrl + b`, `A`) as a fallback.

### Agent dashboard shows "no zellij sessions running"

- Make sure `fzf` is installed.
- Agent sessions are identified by a tab named `agent` or a timestamped session name. The dashboard falls back to all sessions if none match.

### Layout fails to load

- Validate the KDL: `zellij setup --dump-layout agent`.
- Check that `ZELLIJ_AGENT_CMD` is exported if you are loading `agent.kdl` manually.

### Notifications don't appear

- `notify.sh` tries `notify-send`, then WSL toast, then terminal bell. On headless systems only the bell will work.
- Ensure the Claude Code hooks are registered in `~/.claude/settings.json`.

### I broke something — revert to tmux

Everything tmux-related is unchanged. Keep using:

```bash
work ~/dev/myproject
agent-session.sh refactor-auth claude
C-a a   # tmux agent dashboard
```

---

## Files

- `~/dotfiles/config/zellij/config.kdl`
- `~/dotfiles/config/zellij/layouts/{agent,daemon,dev,quad}.kdl`
- `~/dotfiles/config/systemd/user/zellij.service`
- `~/dotfiles/scripts/zellij-agent-session.sh`
- `~/dotfiles/scripts/zellij-agent-dashboard.sh`
- `~/dotfiles/scripts/zellij-agent-worktree.sh`
- `~/dotfiles/scripts/zellij-agent-session-prompt.sh`
- `~/dotfiles/scripts/zellij-agent-worktree-prompt.sh`
- `~/dotfiles/scripts/zellij-service.sh`
- `~/dotfiles/scripts/agent-hook.sh` (shared with tmux)
