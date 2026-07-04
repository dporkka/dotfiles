# ~/.bashrc.d/03-agents.sh
# Agent / AI coding assistant launchers (interactive shells only).
# Each helper is defined only when the corresponding binary exists so that
# sourcing this file on a minimal machine never produces errors.

# Claude Code
if command -v claude >/dev/null 2>&1; then
  cc() { command claude "$@"; }
fi

# OpenAI Codex CLI
if command -v codex >/dev/null 2>&1; then
  cod() { command codex "$@"; }
fi

# Aider multi-repo coding assistant
if command -v aider >/dev/null 2>&1; then
  aider() { command aider "$@"; }
fi

# Antigravity
if command -v antigravity >/dev/null 2>&1; then
  agy() { command antigravity "$@"; }
fi

# Project tmux session helper
if command -v tmux >/dev/null 2>&1; then
  work() {
    local session cols rows
    session="${1:-$(basename "$PWD")}"
    if tmux has-session -t "$session" 2>/dev/null; then
      tmux attach -t "$session"
    else
      cols=$(tput cols 2>/dev/null || echo 80)
      rows=$(tput lines 2>/dev/null || echo 24)
      tmux new-session -d -s "$session" -x "$cols" -y "$rows" 2>/dev/null \
        || tmux new-session -d -s "$session"
      tmux send-keys -t "$session" "cd ${2:-$PWD}" Enter
      tmux attach -t "$session"
    fi
  }
fi

# Launch Claude Code in the current directory (new tmux window when inside tmux).
if command -v claude >/dev/null 2>&1; then
  agent() {
    local task="${1:-}"
    if [[ -n "${TMUX:-}" ]] && command -v tmux >/dev/null 2>&1; then
      local window_name="agent-$(date +%H%M%S)"
      tmux new-window -n "$window_name"
      if [[ -n "$task" ]]; then
        tmux send-keys "claude --task '${task}'" Enter
      else
        tmux send-keys "claude" Enter
      fi
    else
      if [[ -n "$task" ]]; then
        command claude --task "$task"
      else
        command claude
      fi
    fi
  }
fi
