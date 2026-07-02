#!/usr/bin/env bash
# =============================================================================
# agent-hook.sh — called by Claude Code hooks to surface agent state in tmux/zellij
# and mirror that state into the unified agent registry.
#
# Wire in ~/.claude/settings.json:
#   UserPromptSubmit -> agent-hook.sh working    (you just handed it a task)
#   Notification     -> agent-hook.sh waiting     (it needs input / permission)
#   Stop             -> agent-hook.sh done         (it finished a turn)
#
# Effect:
#   * tmux: sets a per-window tmux user option @agent_state, read by the status bar
#     (window glyph + global ⚡/✓ counts) and by agent-dashboard.sh
#   * zellij: renames the current tab with a state prefix (⚡/✓/•)
#   * registry: updates the session's state in ~/.local/state/agents/registry/
#     so cross-multiplexer dashboards can see all agents at once
#   * fires notify.sh (bell + tmux/zellij message + WSL toast)
#
# 'done' only toasts when you are NOT already looking at that pane, so active
# pairing with one agent stays quiet while background agents still ping you.
# Zellij focus detection is best-effort; if we cannot determine focus we default
# to notifying so background agents still ping.
# Always exits 0 — a hook must never block or fail the agent.
# =============================================================================

state="${1:-done}"

# Drain the hook's JSON payload on stdin so Claude Code never blocks on us.
cat >/dev/null 2>&1 || true

label="agent"
focused=0

state_prefix() {
  case "$state" in
    waiting) printf '⚡ ' ;;
    done)    printf '✓ ' ;;
    working) printf '• ' ;;
    *)       printf '' ;;
  esac
}

# Mirror the state into the unified agent registry. This is best-effort: managed
# sessions are registered by agent-worktree.sh / zellij-agent-worktree.sh. If the
# record is missing (e.g. an ad-hoc Claude pane), create it on the fly so the
# unified dashboard/status line can see every agent.
registry_update() {
  local session_name="$1"
  local multiplexer="$2"
  local agent_state="$3"
  local worktree="${4:-$PWD}"
  local record_file="$HOME/.local/state/agents/registry/${session_name}.json"
  if [[ -f "$record_file" ]]; then
    "$HOME/dotfiles/scripts/agent-registry.sh" set-state "$session_name" "$agent_state" >/dev/null 2>&1 || true
  else
    "$HOME/dotfiles/scripts/agent-registry.sh" register "$session_name" "$multiplexer" \
      "worktree=$worktree" "state=$agent_state" >/dev/null 2>&1 || true
  fi
}

if [[ -n "${TMUX:-}" && -n "${TMUX_PANE:-}" ]]; then
  tmux set-option -w -t "$TMUX_PANE" @agent_state "$state" 2>/dev/null || true
  label="$(tmux display-message -p -t "$TMUX_PANE" '#S' 2>/dev/null || echo agent)"
  worktree="$(tmux display-message -p -t "$TMUX_PANE" '#{pane_current_path}' 2>/dev/null || echo "$PWD")"
  registry_update "$label" tmux "$state" "$worktree"
  # focused = a client is attached AND this is the active pane of the active window
  focused="$(tmux display-message -p -t "$TMUX_PANE" \
    '#{&&:#{session_attached},#{&&:#{window_active},#{pane_active}}}' 2>/dev/null || echo 0)"
elif [[ -n "${ZELLIJ_SESSION_NAME:-}" && -n "${ZELLIJ_PANE_ID:-}" ]]; then
  label="$ZELLIJ_SESSION_NAME"
  registry_update "$label" zellij "$state" "$PWD"
  prefix="$(state_prefix)"
  if [[ -n "$prefix" ]]; then
    current_tab="$(zellij action query-tab-names 2>/dev/null | tail -n +2 | head -1 || true)"
    new_tab="$(printf '%s' "$current_tab" | sed 's/^[⚡✓•] //')"
    zellij action rename-tab "${prefix}${new_tab}" 2>/dev/null || true
  fi
  # Zellij focus detection from a background pane is unreliable, so we default
  # to unfocused. This keeps background-agent notifications useful.
  focused=0
fi

ping() { "$HOME/dotfiles/scripts/notify.sh" "$1" "$2" >/dev/null 2>&1 || true; }

case "$state" in
  waiting) ping "🟡 ${label} needs you" "Claude is waiting for input" ;;
  done)    [[ "$focused" != "1" ]] && ping "✅ ${label} finished" "Claude completed a turn" ;;
  working) : ;;  # clear the marker only; no ping while you're actively driving
esac

exit 0
