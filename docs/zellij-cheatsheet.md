# Zellij Cheatsheet

One-page reference for the Zellij + AI-agent setup.

---

## Commands

```bash
zellij                            # new session
zellij attach <session>           # attach
zellij ls                         # list sessions
zellij delete-session <name>      # kill session
zellij delete-all-sessions        # kill everything
zellij setup --check              # validate config
zellij setup --dump-layout agent  # print parsed layout

# Project session
zwork ~/dev/myproject

# AI agents
zellij-agent-session.sh refactor-auth claude
zellij-agent-worktree.sh feat/payments "add MFA"
zellij-agent-dashboard.sh         # unified tmux + Zellij dashboard
zagent "refactor auth middleware"

# Systemd persistence service (keeps Zellij alive across logout/reboot)
zellij-service.sh install           # link unit file
zellij-service.sh enable            # start on login
zellij-service.sh start             # start now
zellij-service.sh status            # check status

# Unified registry
agent-registry.sh list                  # all agents
agent-registry.sh list --json           # JSON output
agent-registry.sh prune                 # remove dead records
agent-registry.sh set-state <session> waiting
agent-registry.sh snapshot              # save timestamped snapshot
agent-registry.sh list-snapshots        # list snapshots
agent-registry.sh restore latest        # restore latest snapshot
agent-registry.sh restore <name>        # restore named snapshot
agent-registry.sh resurrect --dry-run   # preview dead sessions to revive
agent-registry.sh resurrect             # relaunch dead sessions

# Direct registry resurrection (no snapshot needed)
agent-resurrect.sh list                 # dead-but-resurrectable agents
agent-resurrect.sh <session>            # resurrect a specific agent
agent-resurrect.sh all --dry-run        # preview all resurrections
agent-resurrect.sh all                  # resurrect every eligible agent
```

---

## Keys

### Normal mode

| Key | Action |
|---|---|
| `Alt + h/j/k/l` | Focus left/down/up/right |
| `Alt + 1..9` | Go to tab |
| `Alt + n` | New pane |
| `Alt + f` | Toggle floating panes |
| `Alt + =` / `Alt + -` | Resize +/- |
| `Ctrl + t` | Tab mode |
| `Ctrl + p` | Pane mode |
| `Ctrl + n` | Resize mode |
| `Ctrl + o` | Session mode |
| `Ctrl + g` | Lock mode |
| `Ctrl + q` | Quit |

### AI agents

| Key | Action |
|---|---|
| `Alt + a` | Session manager popup |
| `Alt + d` | Agent dashboard (tmux + Zellij) |
| `Alt + Shift + a` | Spawn agent session |
| `Alt + w` | Spawn agent worktree |
| `Alt + r` | List agents from registry |
| `Alt + Shift + r` | Prune dead agent records |

### tmux emulation (`Ctrl + b`, then...)

| Key | Action |
|---|---|
| `\|` | Split vertical |
| `-` | Split horizontal |
| `c` | New tab |
| `h/j/k/l` | Move focus |
| `n` / `p` | Next / prev tab |
| `z` | Zoom pane |
| `x` | Close pane |
| `[` | Scroll mode |
| `a` | Agent dashboard |
| `A` | Spawn agent session |
| `W` | Spawn agent worktree |
| `d` | Detach |

---

## Layouts

| Layout | Use case |
|---|---|
| `agent` | Agent + git watcher + review panes |
| `daemon` | Systemd service holder (do not use manually) |
| `dev` | Editor / terminal split |
| `quad` | Editor + tests + agent + logs |

```bash
zellij --layout agent --session my-agent
zellij --layout dev --session my-project
```

---

## tmux ↔ Zellij map

| tmux | Zellij |
|---|---|
| `tmux ls` | `zellij ls` |
| `tmux attach -t x` | `zellij attach x` |
| `C-a \|` | `Ctrl+b \|` |
| `C-a -` | `Ctrl+b -` |
| `C-a c` | `Ctrl+b c` |
| `C-a hjkl` | `Alt+hjkl` |
| `C-a a` | `Alt+d` |
| `C-a W` | `Alt+w` |
| `prefix [` | `Ctrl+s` |

---

## Claude Code hooks

`~/.claude/settings.json`:

```json
{
  "hooks": {
    "UserPromptSubmit": "bash $HOME/dotfiles/scripts/agent-hook.sh working",
    "Notification": "bash $HOME/dotfiles/scripts/agent-hook.sh waiting",
    "Stop": "bash $HOME/dotfiles/scripts/agent-hook.sh done"
  }
}
```
